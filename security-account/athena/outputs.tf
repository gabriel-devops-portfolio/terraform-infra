############################################
# Outputs for Athena Configuration
############################################

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup for Security Lake queries"
  value       = data.aws_athena_workgroup.security_lake.name
}

output "athena_database_name" {
  description = "Name of the Glue catalog database for Security Lake"
  value       = data.aws_glue_catalog_database.security_lake.name
}

output "athena_named_queries" {
  description = "Map of deployed Athena named queries"
  value = {
    vpc_traffic_anomalies    = aws_athena_named_query.vpc_traffic_anomalies.id
    terraform_state_access   = aws_athena_named_query.terraform_state_access.id
    privileged_activity      = aws_athena_named_query.privileged_activity.id
    guardduty_findings       = aws_athena_named_query.guardduty_findings.id
    failed_auth_attempts     = aws_athena_named_query.failed_auth_attempts.id
    s3_public_access_changes = aws_athena_named_query.s3_public_access_changes.id
    security_group_changes   = aws_athena_named_query.security_group_changes.id
  }
}

output "athena_views" {
  description = "Map of Athena view creation queries"
  value = {
    vpc_traffic_anomalies  = aws_athena_named_query.create_vpc_traffic_anomalies_view.id
    terraform_state_access = aws_athena_named_query.create_terraform_state_view.id
    privileged_activity    = aws_athena_named_query.create_privileged_activity_view.id
    guardduty_findings     = aws_athena_named_query.create_guardduty_view.id
  }
}
