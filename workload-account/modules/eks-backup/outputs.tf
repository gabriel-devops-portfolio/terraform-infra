# Outputs for EKS Backup Module

output "velero_bucket_name" {
  description = "Name of the S3 bucket for Velero backups"
  value       = aws_s3_bucket.velero_backups.bucket
}

output "velero_bucket_arn" {
  description = "ARN of the S3 bucket for Velero backups"
  value       = aws_s3_bucket.velero_backups.arn
}

output "velero_iam_role_arn" {
  description = "ARN of the IAM role for Velero"
  value       = aws_iam_role.velero.arn
}

output "etcd_backup_bucket_name" {
  description = "Name of the S3 bucket for ETCD backups"
  value       = aws_s3_bucket.etcd_backups.bucket
}

output "etcd_backup_bucket_arn" {
  description = "ARN of the S3 bucket for ETCD backups"
  value       = aws_s3_bucket.etcd_backups.arn
}

output "ebs_snapshot_lambda_role_arn" {
  description = "ARN of the IAM role for EBS snapshot Lambda"
  value       = aws_iam_role.ebs_snapshot_lambda.arn
}

output "backup_log_group_name" {
  description = "Name of the CloudWatch log group for backup operations"
  value       = aws_cloudwatch_log_group.backup_operations.name
}

output "backup_failure_alarm_arn" {
  description = "ARN of the CloudWatch alarm for backup failures"
  value       = var.enable_backup_monitoring ? aws_cloudwatch_metric_alarm.backup_failure_alarm[0].arn : null
}
