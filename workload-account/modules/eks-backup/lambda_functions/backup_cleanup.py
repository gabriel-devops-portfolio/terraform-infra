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
    Lambda function to clean up old backup files and snapshots
    """
    try:
        cluster_name = os.environ['CLUSTER_NAME']
        velero_bucket = os.environ['VELERO_BUCKET']
        etcd_bucket = os.environ['ETCD_BUCKET']
        retention_days = int(os.environ.get('RETENTION_DAYS', '30'))

        logger.info(f"Starting backup cleanup for cluster: {cluster_name}")

        # Initialize AWS clients
        s3 = boto3.client('s3')
        ec2 = boto3.client('ec2')

        cleanup_results = {
            'velero_objects_deleted': 0,
            'etcd_objects_deleted': 0,
            'snapshots_deleted': 0
        }

        # Clean up Velero backups
        cleanup_results['velero_objects_deleted'] = cleanup_s3_objects(
            s3, velero_bucket, retention_days, 'Velero'
        )

        # Clean up ETCD backups
        cleanup_results['etcd_objects_deleted'] = cleanup_s3_objects(
            s3, etcd_bucket, retention_days, 'ETCD'
        )

        # Clean up EBS snapshots
        cleanup_results['snapshots_deleted'] = cleanup_ebs_snapshots(
            ec2, cluster_name, retention_days
        )

        logger.info(f"Backup cleanup completed: {cleanup_results}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Backup cleanup completed successfully',
                'cluster_name': cluster_name,
                'results': cleanup_results
            })
        }

    except Exception as e:
        logger.error(f"Error in backup cleanup process: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'cluster_name': cluster_name
            })
        }

def cleanup_s3_objects(s3, bucket_name, retention_days, backup_type):
    """
    Clean up S3 objects older than retention period
    """
    deleted_count = 0
    cutoff_date = datetime.now() - timedelta(days=retention_days)

    try:
        # List all objects in the bucket
        paginator = s3.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=bucket_name)

        objects_to_delete = []

        for page in pages:
            if 'Contents' in page:
                for obj in page['Contents']:
                    # Check if object is older than retention period
                    if obj['LastModified'].replace(tzinfo=None) < cutoff_date:
                        objects_to_delete.append({'Key': obj['Key']})

                        # Delete in batches of 1000 (S3 limit)
                        if len(objects_to_delete) >= 1000:
                            delete_batch(s3, bucket_name, objects_to_delete, backup_type)
                            deleted_count += len(objects_to_delete)
                            objects_to_delete = []

        # Delete remaining objects
        if objects_to_delete:
            delete_batch(s3, bucket_name, objects_to_delete, backup_type)
            deleted_count += len(objects_to_delete)

        logger.info(f"Deleted {deleted_count} old {backup_type} objects from {bucket_name}")
        return deleted_count

    except Exception as e:
        logger.error(f"Error cleaning up {backup_type} objects in {bucket_name}: {str(e)}")
        return 0

def delete_batch(s3, bucket_name, objects_to_delete, backup_type):
    """
    Delete a batch of S3 objects
    """
    try:
        response = s3.delete_objects(
            Bucket=bucket_name,
            Delete={
                'Objects': objects_to_delete,
                'Quiet': True
            }
        )

        if 'Errors' in response and response['Errors']:
            for error in response['Errors']:
                logger.error(f"Failed to delete {backup_type} object {error['Key']}: {error['Message']}")

    except Exception as e:
        logger.error(f"Error deleting batch of {backup_type} objects: {str(e)}")

def cleanup_ebs_snapshots(ec2, cluster_name, retention_days):
    """
    Clean up EBS snapshots older than retention period
    """
    deleted_count = 0
    cutoff_date = datetime.now() - timedelta(days=retention_days)

    try:
        # Find snapshots created by the backup process
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

        for snapshot in snapshots_response['Snapshots']:
            snapshot_date = snapshot['StartTime'].replace(tzinfo=None)

            if snapshot_date < cutoff_date:
                try:
                    ec2.delete_snapshot(SnapshotId=snapshot['SnapshotId'])
                    deleted_count += 1
                    logger.info(f"Deleted old snapshot: {snapshot['SnapshotId']}")
                except Exception as e:
                    logger.error(f"Failed to delete snapshot {snapshot['SnapshotId']}: {str(e)}")

        logger.info(f"Deleted {deleted_count} old EBS snapshots")
        return deleted_count

    except Exception as e:
        logger.error(f"Error cleaning up EBS snapshots: {str(e)}")
        return 0

def cleanup_incomplete_multipart_uploads(s3, bucket_name):
    """
    Clean up incomplete multipart uploads
    """
    try:
        # List incomplete multipart uploads
        response = s3.list_multipart_uploads(Bucket=bucket_name)

        if 'Uploads' in response:
            for upload in response['Uploads']:
                # Abort uploads older than 24 hours
                upload_date = upload['Initiated'].replace(tzinfo=None)
                if upload_date < datetime.now() - timedelta(hours=24):
                    try:
                        s3.abort_multipart_upload(
                            Bucket=bucket_name,
                            Key=upload['Key'],
                            UploadId=upload['UploadId']
                        )
                        logger.info(f"Aborted incomplete multipart upload: {upload['Key']}")
                    except Exception as e:
                        logger.error(f"Failed to abort multipart upload {upload['Key']}: {str(e)}")

    except Exception as e:
        logger.error(f"Error cleaning up multipart uploads in {bucket_name}: {str(e)}")
