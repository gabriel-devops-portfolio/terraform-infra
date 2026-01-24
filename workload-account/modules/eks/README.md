# EKS Cluster Module

This module provisions an Amazon EKS cluster using the `terraform-aws-modules/eks/aws` module as a base. It configures the control plane, worker nodes, networking, and authentication.

## Usage

```hcl
module "eks" {
  source = "../modules/eks"

  eks_cluster_name                         = "my-cluster"
  eks_cluster_version                      = "1.28"
  eks_vpc_id                               = "vpc-12345678"
  subnet_ids                               = ["subnet-1", "subnet-2"]
  eks_kms_arn                              = "arn:aws:kms:..."

  # Node groups and other configurations
  eks_managed_node_groups = {
    # ...
  }
}
```

## Inputs

| Name                                  | Description                               | Type           | Default |
| ------------------------------------- | ----------------------------------------- | -------------- | ------- |
| `eks_cluster_name`                    | Name of the EKS cluster                   | `string`       | `""`    |
| `eks_vpc_id`                          | The VPC ID for the cluster                | `string`       | `""`    |
| `subnet_ids`                          | List of subnets for the cluster           | `any`          | `""`    |
| `eks_cluster_version`                 | Kubernetes version                        | `string`       | `""`    |
| `eks_kms_arn`                         | KMS key ARN for encryption                | `string`       | `""`    |
| `eks_managed_node_groups`             | Map of managed node group configurations  | `map(any)`     | `{}`    |
| `aws_auth_users`                      | List of IAM users to add to aws-auth      | `list(object)` | -       |
| `aws_auth_roles`                      | List of IAM roles to add to aws-auth      | `list(object)` | -       |
| `manage_aws_auth_configmap`           | Whether to manage the aws-auth configmap  | `bool`         | `true`  |
| `eks_cluster_endpoint_public_access`  | Enable public access to cluster endpoint  | `bool`         | `false` |
| `eks_cluster_endpoint_private_access` | Enable private access to cluster endpoint | `bool`         | `true`  |

## Outputs

| Name                                 | Description                                                              |
| ------------------------------------ | ------------------------------------------------------------------------ |
| `cluster_id`                         | The name/ID of the EKS cluster                                           |
| `cluster_arn`                        | The ARN of the EKS cluster                                               |
| `cluster_endpoint`                   | The endpoint for the EKS cluster API                                     |
| `cluster_security_group_id`          | Security group ID attached to the cluster control plane                  |
| `node_security_group_id`             | Security group ID attached to the worker nodes                           |
| `oidc_provider_arn`                  | ARN of the OIDC Provider                                                 |
| `cluster_certificate_authority_data` | Base64 encoded certificate data required to communicate with the cluster |

## Features

- **Private Cluster**: Configured by default for private endpoint access.
- **Managed Node Groups**: Supports defining node groups via variables.
- **IRSA**: Configures OIDC provider for IAM Roles for Service Accounts.
- **Security**:
  - KMS encryption for secrets.
  - Security groups for control plane and nodes.
  - Restricted endpoint access.
- **Add-ons**: Supports installing EKS add-ons.
