"""
Security Lake OCSF Transformer
Transforms Terraform State Access Logs to OCSF format

NOTE: VPC Flow Logs are handled NATIVELY by AWS Security Lake.
      This Lambda only transforms custom logs (Terraform State Access).
"""
import json
import os
import boto3
from datetime import datetime
from urllib.parse import unquote_plus
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
s3 = boto3.client('s3')

# Environment variables
OCSF_VERSION = os.environ.get('OCSF_VERSION', '1.1.0')
TERRAFORM_STATE_LOGS_BUCKET = os.environ['TERRAFORM_STATE_LOGS_BUCKET']
SECURITY_LAKE_CUSTOM_SOURCE_ARN_TERRAFORM = os.environ['SECURITY_LAKE_CUSTOM_SOURCE_ARN_TERRAFORM']


def lambda_handler(event, context):
    """
    Main Lambda handler for OCSF transformation
    Only processes Terraform State Access Logs
    """
    logger.info(f"Processing {len(event['Records'])} S3 events")

    for record in event['Records']:
        try:
            bucket = record['s3']['bucket']['name']
            key = unquote_plus(record['s3']['object']['key'])

            logger.info(f"Processing: s3://{bucket}/{key}")

            # Download S3 object
            response = s3.get_object(Bucket=bucket, Key=key)
            data = response['Body'].read()

            # Transform Terraform State Access Logs
            if bucket == TERRAFORM_STATE_LOGS_BUCKET or 'terraform-state' in key:
                ocsf_events = transform_s3_access_log_to_ocsf(data, bucket, key)
                log_type = "Terraform State Access Logs"
            else:
                logger.warning(f"Unknown log type for: {bucket}/{key}")
                continue

            if not ocsf_events:
                logger.info(f"No events to send for {key}")
                continue

            # Send to Security Lake in batches (max 100 per batch)
            batch_size = 100
            total_sent = 0

            for i in range(0, len(ocsf_events), batch_size):
                batch = ocsf_events[i:i + batch_size]

                # Security Lake expects events in JSON format
                response = s3.put_object(
                    Bucket=f"aws-security-data-lake-{os.environ['AWS_REGION']}-{context.invoked_function_arn.split(':')[4]}",
                    Key=f"ext/{log_type.replace(' ', '_')}/{datetime.utcnow().strftime('%Y/%m/%d')}/{context.request_id}-{i}.json",
                    Body=json.dumps({'events': batch}),
                    ContentType='application/json'
                )

                total_sent += len(batch)
                logger.info(f"Sent batch {i//batch_size + 1}: {len(batch)} events")

            logger.info(f"Successfully sent {total_sent} {log_type} events to Security Lake")

        except Exception as e:
            logger.error(f"Error processing {record}: {str(e)}", exc_info=True)
            # Continue processing other records
            continue

    return {
        'statusCode': 200,
        'body': json.dumps('Processing complete')
    }


def transform_s3_access_log_to_ocsf(data, bucket, key):
    """
    Transform S3 Access Logs (Terraform State) to OCSF API Activity (class 3005)
    """
    try:
        # S3 access logs are plain text format
        log_text = data.decode('utf-8')
        lines = log_text.strip().split('\n')

        logger.info(f"Processing {len(lines)} S3 access log entries")

        ocsf_events = []
        for line in lines:
            try:
                # Parse S3 access log format
                # Format: bucket_owner canonical_user_id timestamp remote_ip requester request_id operation key request_uri http_status error_code bytes_sent object_size total_time turnaround_time referrer user_agent version_id
                parts = line.split(' ')
                if len(parts) < 10:
                    continue

                # Only process if it's related to terraform state
                object_key = parts[7] if len(parts) > 7 else ""
                if 'terraform' not in object_key.lower() and '.tfstate' not in object_key.lower():
                    continue

                operation = parts[6] if len(parts) > 6 else ""
                http_status = parts[8] if len(parts) > 8 else "200"

                # Determine severity: High for GetObject on .tfstate files
                severity_id = 3 if 'GET' in operation and '.tfstate' in object_key else 2

                timestamp_str = parts[2][1:] if len(parts) > 2 else ""  # Remove leading [
                event_time = parse_s3_log_timestamp(timestamp_str)

                ocsf_event = {
                    "metadata": {
                        "version": OCSF_VERSION,
                        "product": {
                            "name": "AWS S3 Access Logs",
                            "vendor_name": "AWS"
                        },
                        "event_code": operation,
                        "profiles": ["cloud"],
                        "log_name": "S3 Access Logs",
                        "log_provider": "AWS S3"
                    },
                    "class_uid": 3005,  # API Activity
                    "class_name": "API Activity",
                    "category_uid": 3,  # Identity & Access Management
                    "category_name": "Identity & Access Management",
                    "severity_id": severity_id,
                    "severity": "High" if severity_id == 3 else "Medium",
                    "time": event_time,
                    "api": {
                        "operation": operation,
                        "service": {
                            "name": "s3.amazonaws.com"
                        },
                        "response": {
                            "code": int(http_status) if http_status.isdigit() else 200,
                            "message": parts[9] if len(parts) > 9 and parts[9] != '-' else None
                        }
                    },
                    "actor": {
                        "user": {
                            "uid": parts[4] if len(parts) > 4 else "unknown",
                            "type": "IAMUser"
                        }
                    },
                    "cloud": {
                        "provider": "AWS",
                        "account": {
                            "uid": parts[0] if len(parts) > 0 else ""
                        }
                    },
                    "src_endpoint": {
                        "ip": parts[3] if len(parts) > 3 else ""
                    },
                    "resources": [
                        {
                            "type": "s3-object",
                            "uid": f"{bucket}/{object_key}",
                            "name": object_key
                        }
                    ],
                    "http_request": {
                        "user_agent": parts[-2] if len(parts) > 15 else "unknown",
                        "http_status": int(http_status) if http_status.isdigit() else 200
                    },
                    "unmapped": {
                        "request_id": parts[5] if len(parts) > 5 else "",
                        "bytes_sent": int(parts[10]) if len(parts) > 10 and parts[10].isdigit() else 0,
                        "object_size": int(parts[11]) if len(parts) > 11 and parts[11].isdigit() else 0,
                        "total_time_ms": int(parts[12]) if len(parts) > 12 and parts[12].isdigit() else 0
                    }
                }

                ocsf_events.append(ocsf_event)

            except Exception as e:
                logger.error(f"Error transforming S3 access log line: {str(e)}")
                continue

        return ocsf_events

    except Exception as e:
        logger.error(f"Error transforming S3 Access Logs: {str(e)}", exc_info=True)
        return []


def parse_s3_log_timestamp(timestamp_str):
    """Parse S3 access log timestamp"""
    try:
        # Format: 06/Feb/2019:00:00:38 +0000
        dt = datetime.strptime(timestamp_str.split('+')[0].strip(), '%d/%b/%Y:%H:%M:%S')
        return int(dt.timestamp() * 1000)
    except Exception:
        return int(datetime.utcnow().timestamp() * 1000)
