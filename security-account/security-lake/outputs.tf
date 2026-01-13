############################################
# Security Lake Outputs
############################################

output "security_lake_arn" {
  description = "ARN of the Security Lake data lake"
  value       = aws_securitylake_data_lake.main.arn
}

output "security_lake_s3_bucket" {
  description = "S3 bucket name used by Security Lake"
  value       = "aws-security-data-lake-${local.region}-${local.security_account_id}"
}

output "security_lake_manager_role_arn" {
  description = "ARN of the Security Lake manager role"
  value       = aws_iam_role.security_lake_manager.arn
}

output "glue_database_name" {
  description = "Glue database name for Security Lake"
  value       = "amazon_security_lake_glue_db_${replace(local.region, "-", "_")}"
}

output "enabled_sources" {
  description = "List of enabled Security Lake sources"
  value = [
    "CLOUD_TRAIL_MGMT",
    "VPC_FLOW",
    "SH_FINDINGS",
    "ROUTE53"
  ]
}

output "opensearch_subscriber_id" {
  description = "ID of the OpenSearch Security Lake subscriber"
  value       = aws_securitylake_subscriber.opensearch.id
}

output "opensearch_subscriber_s3_path" {
  description = "S3 path where OpenSearch can access OCSF data"
  value       = "s3://aws-security-data-lake-${local.region}-${local.security_account_id}/ext/"
}
