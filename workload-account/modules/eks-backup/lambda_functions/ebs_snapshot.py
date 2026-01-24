import boto3
import json
import logging
from datetime import datetime, timedelta
import os

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Lambda function to create EBS snapshots for EKS cluster volumes
    """
    try:
        # Initialize AWS clients
        ec2 = boto3.client('ec2')
        eks = boto3.client('eks')

        cluster_name = os.environ['CLUSTER_NAME']
        retention_days = int(os.environ.get('RETENTION_DAYS', '30'))

        logger.info(f"Starting EBS snapshot process for cluster: {cluster_name}")

        # Get cluster information
        cluster_info = eks.describe_cluster(name=cluster_name)
        cluster_arn = cluster_info['cluster']['arn']

        # Find all EBS volumes associated with the EKS cluster
        volumes = find_cluster_volumes(ec2, cluster_name)

        if not volumes:
            logger.info(f"No EBS volumes found for cluster: {cluster_name}")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'No volumes found for cluster {cluster_name}',
                    'snapshots_created': 0
                })
            }

        # Create snapshots for each volume
        snapshots_created = []
        for volume in volumes:
            try:
                snapshot = create_volume_snapshot(ec2, volume, cluster_name)
                if snapshot:
                    snapshots_created.append(snapshot)
                    logger.info(f"Created snapshot {snapshot['SnapshotId']} for volume {volume['VolumeId']}")
            except Exception as e:
                logger.error(f"Failed to create snapshot for volume {volume['VolumeId']}: {str(e)}")

        # Clean up old snapshots
        cleanup_old_snapshots(ec2, cluster_name, retention_days)

        logger.info(f"EBS snapshot process completed. Created {len(snapshots_created)} snapshots")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully created {len(snapshots_created)} snapshots',
                'snapshots_created': len(snapshots_created),
                'cluster_name': cluster_name
            })
        }

    except Exception as e:
        logger.error(f"Error in EBS snapshot process: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'cluster_name': cluster_name
            })
        }

def find_cluster_volumes(ec2, cluster_name):
    """
    Find all EBS volumes associated with the EKS cluster
    """
    volumes = []

    try:
        # Get all instances with the cluster tag
        instances_response = ec2.describe_instances(
            Filters=[
                {
                    'Name': 'tag:kubernetes.io/cluster/' + cluster_name,
                    'Values': ['owned']
                },
                {
                    'Name': 'instance-state-name',
                    'Values': ['running', 'stopped']
                }
            ]
        )

        instance_ids = []
        for reservation in instances_response['Reservations']:
            for instance in reservation['Instances']:
                instance_ids.append(instance['InstanceId'])

        if not instance_ids:
            logger.info(f"No instances found for cluster: {cluster_name}")
            return volumes

        # Get volumes attached to these instances
        volumes_response = ec2.describe_volumes(
            Filters=[
                {
         'Name': 'attachment.instance-id',
                    'Values': instance_ids
                }
            ]
        )

        volumes = volumes_response['Volumes']

        # Also look for volumes with cluster tags directly
        cluster_volumes_response = ec2.describe_volumes(
            Filters=[
                {
                    'Name': 'tag:kubernetes.io/cluster/' + cluster_name,
                    'Values': ['owned']
                }
            ]
        )

        # Merge and deduplicate volumes
        all_volumes = volumes + cluster_volumes_response['Volumes']
        unique_volumes = {v['VolumeId']: v for v in all_volumes}.values()

        return list(unique_volumes)

    except Exception as e:
        logger.error(f"Error finding cluster volumes: {str(e)}")
        return []

def create_volume_snapshot(ec2, volume, cluster_name):
    """
    Create a snapshot for a given EBS volume
    """
    try:
        volume_id = volume['VolumeId']
        timestamp = datetime.now().strftime('%Y-%m-%d-%H-%M-%S')

        # Create snapshot description
        description = f"EKS-{cluster_name}-{volume_id}-{timestamp}"

        # Create the snapshot
        response = ec2.create_snapshot(
            VolumeId=volume_id,
            Description=description
        )

        snapshot_id = response['SnapshotId']

        # Tag the snapshot
        tags = [
            {
                'Key': 'Name',
                'Value': description
            },
            {
                'Key': 'EKSCluster',
                'Value': cluster_name
            },
            {
                'Key': 'VolumeId',
                'Value': volume_id
            },
            {
                'Key': 'BackupType',
                'Value': 'EKS-EBS-Automated'
            },
            {
                'Key': 'CreatedBy',
                'Value': 'EKS-Backup-Lambda'
            },
            {
                'Key': 'CreatedDate',
                'Value': datetime.now().isoformat()
            }
        ]

        # Copy existing volume tags
        if 'Tags' in volume:
            for tag in volume['Tags']:
                if tag['Key'] not in ['Name', 'EKSCluster', 'VolumeId', 'BackupType', 'CreatedBy', 'CreatedDate']:
                    tags.append(tag)

        ec2.create_tags(
            Resources=[snapshot_id],
            Tags=tags
        )

        return response

    except Exception as e:
        logger.error(f"Error creating snapshot for volume {volume['VolumeId']}: {str(e)}")
        return None

def cleanup_old_snapshots(ec2, cluster_name, retention_days):
    """
    Clean up snapshots older than retention period
    """
    try:
        cutoff_date = datetime.now() - timedelta(days=retention_days)

        # Find snapshots created by this backup process
        snapshots_response = ec2.describe_snapshots(
            OwnerIds=['self'],
            Filters=[
                {
                    'Name': 'tag:EKSCluster',
                    'Values': [cluster_name]
                },
                {
                    'Name': 'tag:BackupType',
                    'Values': ['EKS-EBS-Automated']
                }
            ]
        )

        deleted_count = 0
        for snapshot in snapshots_response['Snapshots']:
            snapshot_date = snapshot['StartTime'].replace(tzinfo=None)

            if snapshot_date < cutoff_date:
                try:
                    ec2.delete_snapshot(SnapshotId=snapshot['SnapshotId'])
                    deleted_count += 1
                    logger.info(f"Deleted old snapshot: {snapshot['SnapshotId']}")
                except Exception as e:
                    logger.error(f"Failed to delete snapshot {snapshot['SnapshotId']}: {str(e)}")

        logger.info(f"Cleaned up {deleted_count} old snapshots")

    except Exception as e:
        logger.error(f"Error during snapshot cleanup: {str(e)}")
