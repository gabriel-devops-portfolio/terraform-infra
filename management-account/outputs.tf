############################
# Organization Outputs
############################

output "organization_id" {
  description = "AWS Organization ID"
  value       = aws_organizations_organization.org.id
}

output "organization_arn" {
  description = "AWS Organization ARN"
  value       = aws_organizations_organization.org.arn
}

output "organization_root_id" {
  description = "Root ID of the organization"
  value       = aws_organizations_organization.org.roots[0].id
}

output "management_account_id" {
  description = "Management account ID"
  value       = aws_organizations_organization.org.master_account_id
}

output "management_account_email" {
  description = "Management account email"
  value       = aws_organizations_organization.org.master_account_email
}

############################
# Organizational Unit Outputs
############################

output "security_ou_id" {
  description = "Security OU ID"
  value       = aws_organizations_organizational_unit.security.id
}

output "security_ou_arn" {
  description = "Security OU ARN"
  value       = aws_organizations_organizational_unit.security.arn
}

output "workloads_ou_id" {
  description = "Workloads OU ID"
  value       = aws_organizations_organizational_unit.workloads.id
}

output "workloads_ou_arn" {
  description = "Workloads OU ARN"
  value       = aws_organizations_organizational_unit.workloads.arn
}

############################
# Member Account Outputs
############################

output "security_account_id" {
  description = "Security account ID"
  value       = aws_organizations_account.security.id
}

output "security_account_arn" {
  description = "Security account ARN"
  value       = aws_organizations_account.security.arn
}

output "security_account_email" {
  description = "Security account email"
  value       = aws_organizations_account.security.email
  sensitive   = true
}

output "workload_account_id" {
  description = "Workload account ID"
  value       = aws_organizations_account.workload.id
}

output "workload_account_arn" {
  description = "Workload account ARN"
  value       = aws_organizations_account.workload.arn
}

output "workload_account_email" {
  description = "Workload account email"
  value       = aws_organizations_account.workload.email
  sensitive   = true
}

############################
# Service Control Policy Outputs
############################

output "scp_deny_leave_org_id" {
  description = "SCP ID for deny leave organization policy"
  value       = aws_organizations_policy.deny_leave_org.id
}

output "scp_deny_root_usage_id" {
  description = "SCP ID for deny root account usage policy"
  value       = aws_organizations_policy.deny_root_usage.id
}

output "scp_require_mfa_id" {
  description = "SCP ID for require MFA policy"
  value       = aws_organizations_policy.require_mfa.id
}

output "scp_enforce_encryption_id" {
  description = "SCP ID for enforce encryption in transit policy"
  value       = aws_organizations_policy.enforce_encryption_in_transit.id
}

############################
# Cross-Account Role ARNs
############################

output "security_account_access_role_arn" {
  description = "ARN of the OrganizationAccountAccessRole in security account"
  value       = "arn:aws:iam::${aws_organizations_account.security.id}:role/OrganizationAccountAccessRole"
}

output "workload_account_access_role_arn" {
  description = "ARN of the OrganizationAccountAccessRole in workload account"
  value       = "arn:aws:iam::${aws_organizations_account.workload.id}:role/OrganizationAccountAccessRole"
}

############################
# AWS Backup Outputs
############################

output "backup_policy_note" {
  description = "Instructions for enabling AWS Backup organization configuration"
  value       = local.backup_policy_note
}

output "backup_setup_command" {
  description = "Instructions for AWS Backup setup"
  value       = local.backup_setup_command
}

############################
# Compute Optimizer Outputs
############################

output "compute_optimizer_note" {
  description = "Instructions for enabling Compute Optimizer"
  value       = local.compute_optimizer_note
}

output "compute_optimizer_command" {
  description = "Command to enable Compute Optimizer"
  value       = local.compute_optimizer_command
}

############################
# License Manager Outputs
############################

output "license_manager_note" {
  description = "Instructions for enabling License Manager"
  value       = local.license_manager_note
}

output "license_manager_command" {
  description = "Command to enable License Manager service role"
  value       = local.license_manager_command
}

############################
# Tag Policy Outputs
############################

output "tag_policy_note" {
  description = "Instructions for tag policy setup"
  value       = local.tag_policy_note
}

output "tag_policy_command" {
  description = "Instructions for tag policy creation"
  value       = local.tag_policy_command
}
