resource "aws_iam_policy" "role" {
  name_prefix = var.role_name
  description = "EKS role policy for cluster ${var.cluster_id}"
  #policy      = data.aws_iam_policy_document.role.json
  policy = jsonencode(var.policy)
}

module "iam_assumable_role_admin" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  #version                       = "2.14.0"
  version     = "~> 4.3"
  create_role = true
  role_name   = var.role_name
  #role_name                     = "aws-load-balancer-controller"
  provider_url                   = var.provider_url
  role_policy_arns               = concat(var.role_policy_arns, [aws_iam_policy.role.arn])
  oidc_fully_qualified_subjects  = ["system:serviceaccount:${var.k8s_service_account_namespace}:${var.k8s_service_account_name}"]
  oidc_fully_qualified_audiences = var.oidc_fully_qualified_audiences
}


output "policy_arn" {
  value = aws_iam_policy.role.arn
}

output "role_arn" {
  value = module.iam_assumable_role_admin.iam_role_arn
}
