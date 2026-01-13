############################
# Data Sources
############################
data "aws_caller_identity" "current" {}

############################
# Workload VPC (Spoke)
############################
module "workload_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.env}-workload-vpc"
  cidr = var.workload_vpc_cidr
  azs  = var.azs

  private_subnets  = var.workload_private_subnets
  database_subnets = var.workload_database_subnets

  ################################
  # Database Subnet Tags
  ################################
  database_subnet_tags = {
    "network-tier" = "database"
  }

  enable_nat_gateway   = false
  enable_dns_support   = true
  enable_dns_hostnames = true
  create_igw           = false

  ################################
  # VPC Flow Logs (Enterprise)
  # Send to Security Account S3 Bucket
  ################################
  enable_flow_log                     = true
  flow_log_destination_type           = "s3"
  flow_log_destination_arn            = var.security_account_vpc_flow_logs_bucket_arn
  flow_log_max_aggregation_interval   = 60
  flow_log_per_hour_partition         = true
  flow_log_file_format                = "parquet"
  flow_log_hive_compatible_partitions = true

  # Disable CloudWatch Logs (using S3 instead)
  create_flow_log_cloudwatch_log_group = false
  create_flow_log_cloudwatch_iam_role  = false

  ################################
  # EKS Tags for Private Subnets
  ################################
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                                                           = "1"
    "kubernetes.io/cluster/${var.cluster_name != "" ? var.cluster_name : "${var.env}-cluster"}" = "shared"
    "karpenter.sh/discovery"                                                                    = var.cluster_name != "" ? var.cluster_name : "${var.env}-cluster"
  }

  tags = merge(var.tags, {
    VPC-Type    = "workload"
    Environment = var.env
  })
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.env}-vpc-endpoints-sg"
  description = "Restrict VPC endpoint access"
  vpc_id      = module.workload_vpc.vpc_id

  ingress {
    description = "TLS from workload subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = module.workload_vpc.private_subnets_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.env
    Purpose     = "vpc-endpoints"
  }
}

locals {
  interface_endpoints = [
    "ecr.api",
    "ecr.dkr",
    "ec2",
    "ec2messages",
    "ssm",
    "ssmmessages",
    "logs",
    "sts",
    "elasticloadbalancing",
    "autoscaling",
    "sqs",
    "sns"
  ]
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.interface_endpoints)

  vpc_id              = module.workload_vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.workload_vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.env}-${each.key}-endpoint"
    Environment = var.env
  }
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = module.workload_vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.workload_vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyAll"
        Effect    = "Deny"
        Principal = "*"
        Action    = "secretsmanager:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowExternalSecretsOnly"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:eks/*"
        Condition = {
          StringEquals = {
            "aws:PrincipalArn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/external-secrets-irsa"
          }
        }
      }
    ]
  })

}

resource "aws_vpc_endpoint" "kms" {
  vpc_id              = module.workload_vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.workload_vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyAllKMS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowExternalSecretsDecryptOnly"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/*"
        Condition = {
          StringEquals = {
            "aws:PrincipalArn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/external-secrets-irsa"
          }
        }
      }
    ]
  })
}

# EKS endpoint (required for private clusters)
resource "aws_vpc_endpoint" "eks" {
  vpc_id              = module.workload_vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.eks"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = module.workload_vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "eks-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.workload_vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.workload_vpc.private_route_table_ids

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowApprovedAccessOnly"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::html-css-app-bucket",
          "arn:aws:s3:::html-css-app-bucket/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.env}-s3-endpoint"
    Environment = var.env
  }
}
