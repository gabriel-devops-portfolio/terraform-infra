############################################
# Security Lake Custom Sources Variables
############################################

variable "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting logs"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for CloudWatch alarms"
  type        = string
}

variable "security_lake_data_lake_arn" {
  description = "ARN of the Security Lake data lake"
  type        = string
  default     = ""
}
