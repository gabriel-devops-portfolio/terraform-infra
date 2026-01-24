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

############################################
# Organization Member Accounts
############################################

output "discovered_organization_accounts" {
  description = "All accounts discovered in the organization"
  value = var.auto_include_new_accounts ? {
    for account in data.aws_organizations_organization.org.accounts :
    account.id => {
      name   = account.name
      email  = account.email
      status = account.status
    }
  } : null
}

output "security_lake_member_accounts" {
  description = "Accounts included in Security Lake configuration"
  value       = local.member_accounts
}

output "auto_include_new_accounts" {
  description = "Whether new organization accounts are automatically included"
  value       = var.auto_include_new_accounts
}

############################################
# Multi-Region Configuration
############################################

output "enabled_regions" {
  description = "List of regions where Security Lake is enabled"
  value       = local.enabled_regions
}

output "multi_region_s3_buckets" {
  description = "Map of S3 bucket names by region"
  value = {
    for region in local.enabled_regions :
    region => "aws-security-data-lake-${region}-${local.security_account_id}"
  }
}

############################################
# Log Sources Configuration
############################################

output "enabled_sources" {
  description = "List of enabled Security Lake sources"
  value = concat(
    [
      "CLOUD_TRAIL_MGMT",
      "VPC_FLOW",
      "SH_FINDINGS",
      "ROUTE53"
    ],
    var.enable_waf_logs ? ["WAF"] : [],
    var.enable_lambda_logs ? ["LAMBDA_EXECUTION"] : [],
    var.enable_network_firewall_logs ? ["NetworkFirewall (Custom)"] : []
  )
}

output "waf_logs_enabled" {
  description = "Whether WAF logs are enabled in Security Lake"
  value       = var.enable_waf_logs
}

output "lambda_logs_enabled" {
  description = "Whether Lambda logs are enabled in Security Lake"
  value       = var.enable_lambda_logs
}

output "network_firewall_logs_enabled" {
  description = "Whether Network Firewall logs are enabled in Security Lake"
  value       = var.enable_network_firewall_logs
}

############################################
# Subscriber Configuration
############################################

output "opensearch_subscriber_id" {
  description = "ID of the OpenSearch Security Lake subscriber"
  value       = aws_securitylake_subscriber.opensearch.id
}

output "opensearch_subscriber_s3_path" {
  description = "S3 path where OpenSearch can access OCSF data"
  value       = "s3://aws-security-data-lake-${local.region}-${local.security_account_id}/ext/"
}

############################################
# Athena Configuration
############################################

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup for Security Lake queries"
  value       = aws_athena_workgroup.security_lake.name
}

output "athena_workgroup_arn" {
  description = "ARN of the Athena workgroup for Security Lake queries"
  value       = aws_athena_workgroup.security_lake.arn
}

output "athena_results_bucket" {
  description = "S3 bucket for Athena query results"
  value       = aws_s3_bucket.athena_results.bucket
}

output "athena_database_name" {
  description = "Glue database name for Athena queries"
  value       = aws_glue_catalog_database.security_lake.name
}

############################################
# Pre-built Queries
############################################

output "available_queries" {
  description = "List of pre-built Athena queries for security analysis"
  value = [
    "HighRiskAPICalls - Detect high-risk API operations",
    "FailedAuthentication - Identify brute force attempts",
    "RootAccountUsage - Monitor root account activity",
    "SuspiciousNetworkTraffic - Detect network anomalies",
    "DataExfiltration - Identify large data transfers",
    "WAFBlockedRequests - Analyze blocked web requests",
    "LambdaAnomalies - Detect serverless security issues",
    "CriticalSecurityFindings - Show high-priority findings",
    "SuspiciousDNSQueries - Identify malicious DNS activity",
    "SecurityIncidentCorrelation - Cross-service threat correlation",
    "ComplianceDashboard - Generate compliance reports",
    "DataVolumeAnalysis - Analyze ingestion trends"
  ]
}

############################################
# Custom Sources
############################################

output "network_firewall_custom_source_name" {
  description = "Name of the Network Firewall custom log source"
  value       = var.enable_network_firewall_logs ? aws_securitylake_custom_log_source.network_firewall[0].source_name : null
}

output "network_firewall_custom_source_version" {
  description = "Version of the Network Firewall custom log source"
  value       = var.enable_network_firewall_logs ? aws_securitylake_custom_log_source.network_firewall[0].source_version : null
}

output "custom_source_crawler_role_arn" {
  description = "ARN of the custom source crawler IAM role"
  value       = var.enable_network_firewall_logs ? aws_iam_role.custom_source_crawler[0].arn : null
}
