############################################
# Workload Account - Cross-Account Outputs
############################################

output "terraform_execution_role_arn" {
  description = "ARN of TerraformExecutionRole"
  value       = aws_iam_role.terraform_execution.arn
}

output "guardduty_member_role_arn" {
  description = "ARN of GuardDuty member role"
  value       = aws_iam_role.guardduty_member.arn
}

output "securityhub_member_role_arn" {
  description = "ARN of Security Hub member role"
  value       = aws_iam_role.securityhub_member.arn
}

output "security_lake_query_role_arn" {
  description = "ARN of Security Lake query role"
  value       = aws_iam_role.security_lake_query.arn
}

output "cloudwatch_logs_sender_role_arn" {
  description = "ARN of CloudWatch Logs sender role"
  value       = aws_iam_role.cloudwatch_logs_sender.arn
}

output "vpc_flow_logs_role_arn" {
  description = "ARN of VPC Flow Logs role"
  value       = aws_iam_role.vpc_flow_logs.arn
}

output "detective_member_role_arn" {
  description = "ARN of Detective member role"
  value       = aws_iam_role.detective_member.arn
}

output "cloudtrail_role_arn" {
  description = "ARN of CloudTrail role"
  value       = aws_iam_role.cloudtrail.arn
}

############################################
# Security Account Bucket Names
############################################
output "security_account_cloudtrail_bucket" {
  description = "CloudTrail logs bucket in security account"
  value       = "org-cloudtrail-logs-security-${local.security_account_id}"
}

output "security_account_vpc_flow_logs_bucket" {
  description = "VPC Flow Logs bucket in security account"
  value       = "org-vpc-flow-logs-security-${local.security_account_id}"
}

output "security_account_security_lake_bucket" {
  description = "Security Lake data bucket in security account"
  value       = "org-security-lake-data-${local.security_account_id}"
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
    guardduty_member = {
      arn  = aws_iam_role.guardduty_member.arn
      name = aws_iam_role.guardduty_member.name
    }
    securityhub_member = {
      arn  = aws_iam_role.securityhub_member.arn
      name = aws_iam_role.securityhub_member.name
    }
    security_lake_query = {
      arn  = aws_iam_role.security_lake_query.arn
      name = aws_iam_role.security_lake_query.name
    }
  }
}
