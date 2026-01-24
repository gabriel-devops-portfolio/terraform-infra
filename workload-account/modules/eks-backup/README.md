# EKS Backup Module

This module enables comprehensive backup and recovery capabilities for EKS clusters, including:

- **Velero**: Backup of Kubernetes resources and Persistent Volumes.
- **S3 Bucket**: Secure storage for backups with encryption and lifecycle management.
- **IAM**: Roles and policies for Velero and backup operations.
- **Monitoring**: CloudWatch monitoring and alerting for backup failures.
- **Cross-Region Replication**: Optional replication to a DR region.

## Usage

```hcl
module "eks_backup" {
  source = "../modules/eks-backup"

  cluster_name        = "my-cluster"
  oidc_provider_arn   = "arn:aws:iam::123456789012:oidc-provider/..."
  kms_key_arn         = "arn:aws:kms:..."

  # Optional configurations
  backup_retention_days      = 30
  enable_cross_region_backup = true
  dr_backup_bucket_arn       = "arn:aws:s3:::dr-bucket"
  dr_kms_key_arn             = "arn:aws:kms:..."
}
```

## Inputs

| Name                         | Description                            | Type          | Default       | Required |
| ---------------------------- | -------------------------------------- | ------------- | ------------- | :------: |
| `cluster_name`               | Name of the EKS cluster                | `string`      | -             |   yes    |
| `oidc_provider_arn`          | ARN of the OIDC provider for IRSA      | `string`      | -             |   yes    |
| `kms_key_arn`                | ARN of the KMS key for encryption      | `string`      | -             |   yes    |
| `tags`                       | Tags to apply to resources             | `map(string)` | `{}`          |    no    |
| `backup_retention_days`      | Days to retain Velero backups          | `number`      | `30`          |    no    |
| `etcd_backup_retention_days` | Days to retain ETCD backups            | `number`      | `7`           |    no    |
| `enable_cross_region_backup` | Enable cross-region backup replication | `bool`        | `false`       |    no    |
| `dr_backup_bucket_arn`       | ARN of the DR backup bucket            | `string`      | `null`        |    no    |
| `dr_kms_key_arn`             | ARN of the DR KMS key                  | `string`      | `null`        |    no    |
| `enable_backup_monitoring`   | Enable CloudWatch monitoring           | `bool`        | `true`        |    no    |
| `sns_topic_arn`              | SNS topic for failure notifications    | `string`      | `null`        |    no    |
| `backup_schedule`            | Cron schedule for backups              | `string`      | `"0 2 * * *"` |    no    |
| `enable_velero`              | Enable Velero backups                  | `bool`        | `true`        |    no    |
| `enable_ebs_snapshots`       | Enable EBS snapshots                   | `bool`        | `true`        |    no    |
| `enable_etcd_backup`         | Enable ETCD backup                     | `bool`        | `false`       |    no    |

## Outputs

| Name                       | Description                                     |
| -------------------------- | ----------------------------------------------- |
| `velero_bucket_name`       | Name of the S3 bucket for Velero backups        |
| `velero_bucket_arn`        | ARN of the S3 bucket for Velero backups         |
| `velero_iam_role_arn`      | ARN of the IAM role for Velero                  |
| `etcd_backup_bucket_name`  | Name of the S3 bucket for ETCD backups          |
| `backup_log_group_name`    | CloudWatch log group for backup operations      |
| `backup_failure_alarm_arn` | ARN of the CloudWatch alarm for backup failures |
