############################################
# Cross-Account Roles Module
# This MUST be created first as it provisions:
# - IAM roles for cross-account access
# - S3 buckets for logs and state
# - KMS keys for encryption
# All other modules depend on these resources
############################################
module "cross-account-role" {
  source = "../cross-account-roles"
}

############################################
# OpenSearch Module
# Depends on: cross-account-role (for IAM roles and S3 buckets)
############################################
module "opensearch" {
  source = "../opensearch"

  depends_on = [module.cross-account-role]
}

############################################
# Security Lake Module
# Depends on: cross-account-role (for IAM roles and S3 buckets)
############################################
module "security-lake" {
  source = "../security-lake"

  opensearch_role_arn = module.cross-account-role.opensearch_role_arn

  depends_on = [module.cross-account-role]
}

############################################
# Athena Queries Module
# Depends on: security-lake (for Glue database and Athena workgroup)
############################################
module "athena" {
  source = "../athena"

  region              = var.region
  security_account_id = var.security_account_id
  workload_account_id = var.workload_account_id

  depends_on = [module.security-lake]
}

############################################
# SOC Alerting Module
# Depends on: cross-account-role (for IAM roles and SNS access)
############################################
module "soc-alerting" {
  source = "../soc-alerting"

  depends_on = [module.cross-account-role]
}

############################################
# Config Drift Detection Module
# Depends on: cross-account-role (for IAM roles and S3 buckets)
############################################
module "config-drift-detection" {
  source = "../config-drift-detection"

  # Use the CloudTrail logs bucket for Config data
  config_bucket_name = module.cross-account-role.cloudtrail_logs_bucket_name

  depends_on = [module.cross-account-role]
}

############################################
# Security Lake Custom Sources Module
# Depends on: security-lake (for data lake), cross-account-role (for S3 buckets and KMS)
# Purpose: Transform VPC Flow Logs and Terraform State access logs to OCSF format
############################################
module "security-lake-custom-sources" {
  source = "../security-lake-custom-sources"

  kms_key_arn   = module.cross-account-role.kms_key_arn
  sns_topic_arn = module.soc-alerting.high_topic_arn

  depends_on = [
    module.security-lake,
    module.cross-account-role,
    module.soc-alerting
  ]
}
