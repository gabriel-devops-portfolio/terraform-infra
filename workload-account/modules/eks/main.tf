
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
    "karpenter.sh/discovery"                        = var.eks_cluster_name
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

module "karpenter_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "pilotgab-prod-Karpenter-IRSA"

  oidc_providers = {
    main = {
      provider_arn               = module.eks-cluster.oidc_provider_arn
      namespace_service_accounts = ["karpenter:karpenter"]
    }
  }

  role_policy_arns = {
    policy = aws_iam_policy.karpenter_controller.arn
  }

  tags = var.tags
}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "pilotgab-prod-KarpenterControllerPolicy"
  description = "Policy for Karpenter controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:DeleteLaunchTemplate",
          "ec2:RunInstances",
          "ec2:TerminateInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = module.eks-cluster.eks_managed_node_groups["internal"].iam_role_arn
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = module.eks-cluster.cluster_arn
      },
      {
        Effect = "Allow"
        Action = [
          "pricing:GetProducts"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:us-east-1::parameter/aws/service/*"
      }
    ]
  })
}
