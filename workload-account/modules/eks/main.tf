
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

module "eks-cluster" {
  source                                     = "terraform-aws-modules/eks/aws"
  version                                    = "18.30.2"
  enable_irsa                                = true
  create_cluster_primary_security_group_tags = false
  cluster_name                               = var.eks_cluster_name
  cluster_version                            = var.eks_cluster_version
  subnet_ids                                 = var.subnet_ids
  vpc_id                                     = var.eks_vpc_id
  tags                                       = var.eks_cluster_tags
  manage_aws_auth_configmap                  = var.manage_aws_auth_configmap
  aws_auth_roles                             = var.aws_auth_roles
  aws_auth_users                             = var.aws_auth_users
  aws_auth_accounts                          = var.aws_auth_accounts
  cluster_encryption_config                  = var.eks_cluster_encryption_config
  cluster_endpoint_public_access             = var.eks_cluster_endpoint_public_access
  cluster_endpoint_private_access            = var.eks_cluster_endpoint_private_access
  cluster_enabled_log_types                  = var.cluster_enabled_log_types
  eks_managed_node_groups                    = var.eks_managed_node_groups
  cluster_addons                             = var.cluster_addons
  cluster_security_group_additional_rules    = var.cluster_security_group_additional_rules
  node_security_group_additional_rules       = var.node_security_group_additional_rules
  cloudwatch_log_group_retention_in_days     = var.cloud_watch_log_group_retention_period
  cluster_endpoint_public_access_cidrs       = var.cluster_endpoint_public_access_cidrs
  node_security_group_tags = {
    "kubernetes.io/cluster/${var.eks_cluster_name}" = var.eks_cluster_name
  }
}

resource "kubectl_manifest" "gp3" {
  yaml_body = var.storage_class_yaml
}

resource "aws_iam_role" "eks_full_access" {
  name = var.eks_full_access_role
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Effect": "Allow",
            "Principal": {
               "AWS": [
                  "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
                ]
            }
        }
    ]
}
EOF
}


