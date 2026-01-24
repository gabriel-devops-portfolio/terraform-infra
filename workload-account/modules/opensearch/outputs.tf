############################################
# OpenSearch Module Outputs
############################################

output "opensearch_domain_arn" {
  description = "ARN of the OpenSearch domain"
  value       = aws_opensearch_domain.jaeger.arn
}

output "opensearch_domain_id" {
  description = "Unique identifier for the OpenSearch domain"
  value       = aws_opensearch_domain.jaeger.domain_id
}

output "opensearch_domain_name" {
  description = "Name of the OpenSearch domain"
  value       = aws_opensearch_domain.jaeger.domain_name
}

output "opensearch_endpoint" {
  description = "Domain-specific endpoint used to submit index, search, and data upload requests"
  value       = aws_opensearch_domain.jaeger.endpoint
}

output "opensearch_dashboard_endpoint" {
  description = "Domain-specific endpoint for OpenSearch Dashboards"
  value       = aws_opensearch_domain.jaeger.dashboard_endpoint
}

output "jaeger_elasticsearch_role_arn" {
  description = "ARN of the IAM role for Jaeger to access OpenSearch"
  value       = aws_iam_role.jaeger_opensearch.arn
}

output "jaeger_elasticsearch_role_name" {
  description = "Name of the IAM role for Jaeger to access OpenSearch"
  value       = aws_iam_role.jaeger_opensearch.name
}

output "opensearch_security_group_id" {
  description = "ID of the security group for OpenSearch domain"
  value       = aws_security_group.opensearch.id
}

output "kms_key_id" {
  description = "KMS key ID used for OpenSearch encryption"
  value       = aws_kms_key.opensearch.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN used for OpenSearch encryption"
  value       = aws_kms_key.opensearch.arn
}

############################################
# Jaeger Configuration Values
############################################

output "jaeger_elasticsearch_config" {
  description = "Configuration values for Jaeger Helm chart"
  value = {
    host        = aws_opensearch_domain.jaeger.endpoint
    port        = 443
    scheme      = "https"
    indexPrefix = var.jaeger_index_prefix
    roleArn     = aws_iam_role.jaeger_opensearch.arn
  }
}

output "jaeger_helm_values" {
  description = "Complete Helm values for Jaeger deployment"
  value = templatefile("${path.module}/templates/jaeger-values.yaml", {
    opensearch_endpoint = aws_opensearch_domain.jaeger.endpoint
    role_arn            = aws_iam_role.jaeger_opensearch.arn
    account_id          = local.account_id
    index_prefix        = var.jaeger_index_prefix
    namespace           = var.jaeger_namespace
  })
}
