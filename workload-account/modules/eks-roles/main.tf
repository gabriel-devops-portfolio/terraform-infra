
data "aws_eks_cluster" "cluster" {
  name = var.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.aws_eks_cluster.cluster.name
}


data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


resource "kubectl_manifest" "rw_role" {
  yaml_body = <<YAML
  apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: rw_user-binding
    namespace: default
  subjects:
  - kind: User
    name: rw_user
    apiGroup: rbac.authorization.k8s.io
  roleRef:
    kind: ClusterRole
    name: edit
    apiGroup: rbac.authorization.k8s.io
  YAML
}
