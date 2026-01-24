# KMS Module

This module manages KMS keys for EKS and S3 encryption.

## Usage

```hcl
module "kms" {
  source = "../modules/kms"

  environment         = "prod"
  enable_key_rotation = true
}
```

## Inputs

| Name                           | Description                             | Type     | Default | Required |
| ------------------------------ | --------------------------------------- | -------- | ------- | :------: |
| `environment`                  | The environment name (e.g., prod, dev). | `string` | `null`  |    no    |
| `enable_key_rotation`          | Enable KMS Key automatic rotation.      | `bool`   | `true`  |    no    |
| `enable_custom_kms_key_policy` | Enable custom KMS Key policy.           | `bool`   | `false` |    no    |
| `custom_kms_key_policy`        | Custom KMS Key policy JSON.             | `any`    | `null`  |    no    |

## Outputs

| Name              | Description                |
| ----------------- | -------------------------- |
| `eks_kms_key_arn` | ARN of the KMS key for EKS |
| `eks_kms_key_id`  | ID of the KMS key for EKS  |
| `s3_kms_key_arn`  | ARN of the KMS key for S3  |
| `s3_kms_key_id`   | ID of the KMS key for S3   |
