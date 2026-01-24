# IAM Roles for Service Accounts (IRSA) Module

This module simplifies the creation of IAM roles that can be assumed by Kubernetes Service Accounts using OIDC. It acts as a wrapper around the `terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc` module.

## Usage

```hcl
module "irsa_example" {
  source = "../modules/irsa"

  role_name                     = "my-app-role"
  cluster_id                    = "my-cluster"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  k8s_service_account_namespace = "default"
  k8s_service_account_name      = "my-app-sa"

  policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = "*"
      }
    ]
  }
}
```

## Inputs

| Name                             | Description                                              | Type           | Default | Required |
| -------------------------------- | -------------------------------------------------------- | -------------- | ------- | :------: |
| `role_name`                      | The name of the IAM role.                                | `string`       | -       |   yes    |
| `cluster_id`                     | The Cluster ID to assign this role to (for description). | `string`       | `""`    |    no    |
| `provider_url`                   | The OIDC provider URL (without `https://`).              | `string`       | `""`    |    no    |
| `k8s_service_account_namespace`  | The Kubernetes namespace for the service account.        | `string`       | `""`    |    no    |
| `k8s_service_account_name`       | The Kubernetes service account name.                     | `string`       | `""`    |    no    |
| `policy`                         | The IAM policy JSON object to attach to the role.        | `any`          | `{}`    |    no    |
| `role_policy_arns`               | List of ARNs of existing IAM policies to attach.         | `list(string)` | `[]`    |    no    |
| `oidc_fully_qualified_audiences` | The audience to be used for the OIDC provider.           | `list(string)` | `[]`    |    no    |

## Outputs

| Name         | Description                        |
| ------------ | ---------------------------------- |
| `role_arn`   | The ARN of the created IAM role.   |
| `policy_arn` | The ARN of the created IAM policy. |
