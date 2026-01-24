# RBAC Module

This module manages Kubernetes ClusterRoles and ClusterRoleBindings.

## Usage

```hcl
module "rbac" {
  source = "../modules/rbac"

  cluster_id                 = "my-cluster"
  eks_cluster_ca_certificate = "..."
  account_id                 = "123456789012"

  cluster_role_name          = "my-role"
  create_cluster_role        = true

  rules = [
    {
      api_groups = ["*"]
      resources  = ["*"]
      verbs      = ["get", "list"]
    }
  ]

  cluster_role_binding_name = "my-binding"
  subjects = [
    {
      kind      = "User"
      name      = "my-user"
      api_group = "rbac.authorization.k8s.io"
    }
  ]
}
```

## Inputs

| Name                         | Description                                 | Type           | Default | Required |
| ---------------------------- | ------------------------------------------- | -------------- | ------- | :------: |
| `cluster_id`                 | EKS Cluster ID                              | `string`       | -       |   yes    |
| `eks_cluster_ca_certificate` | Base64 encoded CA certificate               | `string`       | -       |   yes    |
| `account_id`                 | AWS Account ID                              | `string`       | -       |   yes    |
| `cluster_role_name`          | Name of the ClusterRole                     | `string`       | -       |   yes    |
| `create_cluster_role`        | Whether to create the ClusterRole           | `bool`         | `false` |    no    |
| `cluster_role_binding_name`  | Name of the ClusterRoleBinding              | `string`       | -       |   yes    |
| `rules`                      | List of rules for the ClusterRole           | `list(object)` | `[{}]`  |    no    |
| `subjects`                   | List of subjects for the ClusterRoleBinding | `list(object)` | -       |   yes    |
