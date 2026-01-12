############################################
# OpenSearch Outputs
############################################

output "opensearch_endpoint" {
  description = "OpenSearch domain endpoint"
  value       = "https://${aws_opensearch_domain.security_logs.endpoint}"
}

output "opensearch_dashboard_endpoint" {
  description = "OpenSearch Dashboards endpoint"
  value       = "https://${aws_opensearch_domain.security_logs.endpoint}/_dashboards"
}

output "opensearch_domain_arn" {
  description = "ARN of the OpenSearch domain"
  value       = aws_opensearch_domain.security_logs.arn
}

output "opensearch_domain_id" {
  description = "ID of the OpenSearch domain"
  value       = aws_opensearch_domain.security_logs.domain_id
}

output "opensearch_admin_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing OpenSearch admin password"
  value       = aws_secretsmanager_secret.opensearch_admin.arn
  sensitive   = true
}

output "opensearch_security_group_id" {
  description = "Security group ID for OpenSearch domain"
  value       = aws_security_group.opensearch.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for OpenSearch encryption"
  value       = aws_kms_key.opensearch.arn
}

output "opensearch_sns_role_arn" {
  description = "ARN of the IAM role for OpenSearch to publish to SNS"
  value       = aws_iam_role.opensearch_sns.arn
}

output "opensearch_sns_role_name" {
  description = "Name of the IAM role for OpenSearch to publish to SNS"
  value       = aws_iam_role.opensearch_sns.name
}
