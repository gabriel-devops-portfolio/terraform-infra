############################################
# Security Lake Custom Sources Outputs
# NOTE: VPC Flow Logs use native Security Lake ingestion
############################################

output "terraform_state_custom_source_arn" {
  description = "ID of the Terraform State Access custom source in Security Lake"
  value       = aws_securitylake_custom_log_source.terraform_state_access.id
}

output "lambda_function_arn" {
  description = "ARN of the Lambda OCSF transformer function"
  value       = aws_lambda_function.ocsf_transformer.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda OCSF transformer function"
  value       = aws_lambda_function.ocsf_transformer.function_name
}

output "lambda_cloudwatch_log_group" {
  description = "CloudWatch Log Group for Lambda function"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "custom_sources" {
  description = "Security Lake custom sources information"
  value = {
    terraform_state_access = {
      name    = aws_securitylake_custom_log_source.terraform_state_access.source_name
      version = aws_securitylake_custom_log_source.terraform_state_access.source_version
      id      = aws_securitylake_custom_log_source.terraform_state_access.id
    }
  }
}
