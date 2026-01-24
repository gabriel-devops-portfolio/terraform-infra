# Variables for EKS Backup Module

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "backup_retention_days" {
  description = "Number of days to retain Velero backups"
  type        = number
  default     = 30
}

variable "etcd_backup_retention_days" {
  description = "Number of days to retain ETCD backups"
  type        = number
  default     = 7
}

variable "enable_cross_region_backup" {
  description = "Enable cross-region backup replication"
  type        = bool
  default     = false
}

variable "dr_backup_bucket_arn" {
  description = "ARN of the disaster recovery backup bucket"
  type        = string
  default     = null
}

variable "dr_kms_key_arn" {
  description = "ARN of the KMS key in the DR region"
  type        = string
  default     = null
}

variable "enable_backup_monitoring" {
  description = "Enable CloudWatch monitoring for backups"
  type        = bool
  default     = true
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for backup failure notifications"
  type        = string
  default     = null
}

variable "backup_schedule" {
  description = "Cron schedule for automated backups"
  type        = string
  default     = "0 2 * * *" # Daily at 2 AM
}

variable "enable_velero" {
  description = "Enable Velero for Kubernetes resource backups"
  type        = bool
  default     = true
}

variable "enable_ebs_snapshots" {
  description = "Enable automated EBS volume snapshots"
  type        = bool
  default     = true
}

variable "enable_etcd_backup" {
  description = "Enable ETCD backup (for self-managed clusters)"
  type        = bool
  default     = false
}
