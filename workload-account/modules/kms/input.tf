
variable "environment" {
  description = "the env name"
  type        = string
  default     = null
}
variable "enable_key_rotation" {
  default     = true
  description = "Enable KMS Key automatic rotation"
}

variable "enable_custom_kms_key_policy" {
  default     = false
  description = "Enable custom KMS Key policy"
}

variable "custom_kms_key_policy" {
  default     = null
  description = "Custom KMS Key policy"
}
