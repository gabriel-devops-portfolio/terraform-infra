# EKS Roles Module

This module manages RBAC roles and bindings within an EKS cluster using the `kubectl` provider.

## Usage

```hcl
module "eks_roles" {
  source = "../modules/eks-roles"

  cluster_id = "my-cluster"
}
```

## Inputs

| Name         | Description                | Type     | Default | Required |
| ------------ | -------------------------- | -------- | ------- | :------: |
| `cluster_id` | The ID of the EKS cluster. | `string` | -       |   yes    |

## Resources

- `kubectl_manifest.rw_role`: Creates a RoleBinding in the `default` namespace granting `edit` permission to user `rw_user`.
