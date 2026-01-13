############################################
# Security Account - Cross-Account Outputs
############################################

output "terraform_execution_role_arn" {
  description = "ARN of TerraformExecutionRole"
  value       = aws_iam_role.terraform_execution.arn
}

output "guardduty_admin_role_arn" {
  description = "ARN of GuardDuty organization admin role"
  value       = aws_iam_role.guardduty_admin.arn
}

output "securityhub_admin_role_arn" {
  description = "ARN of Security Hub organization admin role"
  value       = aws_iam_role.securityhub_admin.arn
}

output "config_aggregator_role_arn" {
  description = "ARN of Config aggregator role"
  value       = aws_iam_role.config_aggregator.arn
}

output "security_lake_role_arn" {
  description = "ARN of Security Lake role"
  value       = aws_iam_role.security_lake.arn
}

output "security_lake_subscriber_role_arn" {
  description = "ARN of Security Lake subscriber role"
  value       = aws_iam_role.security_lake_subscriber.arn
}

output "detective_admin_role_arn" {
  description = "ARN of Detective organization admin role"
  value       = aws_iam_role.detective_admin.arn
}

output "cloudwatch_logs_receiver_role_arn" {
  description = "ARN of CloudWatch Logs receiver role"
  value       = aws_iam_role.cloudwatch_logs_receiver.arn
}

output "athena_query_role_arn" {
  description = "ARN of Athena security query role"
  value       = aws_iam_role.athena_query.arn
}

output "opensearch_role_arn" {
  description = "ARN of OpenSearch security role"
  value       = aws_iam_role.opensearch.arn
}

############################################
# KMS Key Outputs
############################################
output "kms_key_arn" {
  description = "ARN of the KMS key for security logs encryption"
  value       = aws_kms_key.security_logs.arn
}

output "kms_key_id" {
  description = "ID of the KMS key for security logs encryption"
  value       = aws_kms_key.security_logs.id
}

############################################
# S3 Bucket Outputs
############################################
output "cloudtrail_logs_bucket_arn" {
  description = "ARN of CloudTrail logs S3 bucket"
  value       = aws_s3_bucket.cloudtrail_logs.arn
}

output "cloudtrail_logs_bucket_name" {
  description = "Name of CloudTrail logs S3 bucket"
  value       = aws_s3_bucket.cloudtrail_logs.id
}

output "vpc_flow_logs_bucket_arn" {
  description = "ARN of VPC Flow Logs S3 bucket"
  value       = aws_s3_bucket.vpc_flow_logs.arn
}

output "vpc_flow_logs_bucket_name" {
  description = "Name of VPC Flow Logs S3 bucket"
  value       = aws_s3_bucket.vpc_flow_logs.id
}

output "security_lake_data_bucket_arn" {
  description = "ARN of Security Lake data S3 bucket"
  value       = aws_s3_bucket.security_lake_data.arn
}

output "security_lake_data_bucket_name" {
  description = "Name of Security Lake data S3 bucket"
  value       = aws_s3_bucket.security_lake_data.id
}

output "athena_results_bucket_arn" {
  description = "ARN of Athena query results S3 bucket"
  value       = aws_s3_bucket.athena_results.arn
}

output "athena_results_bucket_name" {
  description = "Name of Athena query results S3 bucket"
  value       = aws_s3_bucket.athena_results.id
}

############################################
# Summary Output
############################################
output "cross_account_roles_summary" {
  description = "Summary of all cross-account roles created"
  value = {
    terraform_execution = {
      arn  = aws_iam_role.terraform_execution.arn
      name = aws_iam_role.terraform_execution.name
    }
    guardduty_admin = {
      arn  = aws_iam_role.guardduty_admin.arn
      name = aws_iam_role.guardduty_admin.name
    }
    securityhub_admin = {
      arn  = aws_iam_role.securityhub_admin.arn
      name = aws_iam_role.securityhub_admin.name
    }
    config_aggregator = {
      arn  = aws_iam_role.config_aggregator.arn
      name = aws_iam_role.config_aggregator.name
    }
    security_lake = {
      arn  = aws_iam_role.security_lake.arn
      name = aws_iam_role.security_lake.name
    }
    detective_admin = {
      arn  = aws_iam_role.detective_admin.arn
      name = aws_iam_role.detective_admin.name
    }
  }
}
