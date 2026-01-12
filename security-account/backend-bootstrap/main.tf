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

  depends_on = [module.cross-account-role]
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
