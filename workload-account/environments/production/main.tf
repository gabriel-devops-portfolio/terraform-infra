data "aws_availability_zones" "available" {
  state = "available"
}

############################
# Local Values
############################
locals {
  cluster_name = "${var.env}-eks-cluster"

  auth_users = var.auth_users != null ? var.auth_users : []
  auth_roles = var.auth_roles != null ? var.auth_roles : []
}

############################
# Networking Module (Hub & Spoke)
############################
module "network" {
  source = "../../modules/networking"

  env    = var.env
  region = var.region
  azs    = var.azs

  # EKS Configuration
  cluster_name = local.cluster_name

  # Workload VPC (Spoke)
  workload_vpc_cidr         = var.workload_vpc_cidr
  workload_private_subnets  = var.workload_private_subnets
  workload_database_subnets = var.workload_database_subnets

  # Egress VPC (Hub)
  egress_vpc_cidr       = var.egress_vpc_cidr
  egress_public_subnets = var.egress_public_subnets
  firewall_subnets      = var.firewall_subnets
  tgw_subnets           = var.tgw_subnets

  enable_nat = var.enable_nat

  tags = var.tags
}

############################
# Security Module
############################
module "security" {
  source = "../../modules/security"

  region               = var.region
  env                  = var.env
  firewall_name        = module.network.firewall_name
  tgw_route_table_id   = module.network.tgw_inspection_route_table_id
  egress_attachment_id = module.network.egress_tgw_attachment_id
}

############################
# Data Module
############################
module "data" {
  source = "../../modules/data"

  env = var.env

  # Network Configuration
  vpc_id           = module.network.workload_vpc_id
  database_subnets = module.network.workload_database_subnets

  # Security Configuration
  eks_cluster_security_group_id = module.kubernetes.cluster_security_group_id

  # KMS Configuration (optional)
  kms_key_arn = module.kms.eks_kms_key_arn

  # RDS Configuration (optional overrides)
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_engine_version    = var.db_engine_version

  depends_on = [
    module.network,
    module.kubernetes
  ]
}

############################
# KMS Module (for EKS encryption)
############################
module "kms" {
  source      = "../../modules/kms"
  environment = var.env
}

############################
# Route53 and ACM (before EKS for certificates)
############################
resource "aws_route53_zone" "primary" {
  name = var.domain_name

  tags = merge(var.tags, {
    Name = "${var.env}-primary-zone"
  })
}

resource "aws_acm_certificate" "eks_cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}"
  ]

  tags = merge(var.tags, {
    Name        = "${var.env}-eks-certificate"
    Environment = var.env
  })

  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation records for ACM certificate
resource "aws_route53_record" "eks_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.eks_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.primary.zone_id
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "eks_cert" {
  certificate_arn         = aws_acm_certificate.eks_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.eks_cert_validation : record.fqdn]
}

############################
# EKS Cluster Module
############################
module "kubernetes" {
  source = "../../modules/eks"

  # Basic Configuration
  eks_cluster_name    = local.cluster_name
  eks_cluster_version = var.eks_cluster_version

  # Network Configuration - CRITICAL: Using Workload VPC
  eks_vpc_id = module.network.workload_vpc_id
  subnet_ids = module.network.workload_private_subnets

  # Security Configuration
  eks_kms_arn                          = module.kms.eks_kms_key_arn
  eks_cluster_endpoint_private_access  = true
  eks_cluster_endpoint_public_access   = false
  cluster_endpoint_public_access_cidrs = var.eks_cluster_endpoint_public_access_cidrs

  # Logging Configuration
  cloud_watch_log_group_retention_period = var.cloudwatch_log_retention_days
  cluster_enabled_log_types              = ["api", "audit", "controllerManager", "scheduler", "authenticator"]

  # Output Configuration
  eks_config_output_path = "${var.eks_config_output_dir_path}/kubeconfig_${local.cluster_name}"

  # Security Group Rules
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # Tags
  eks_cluster_tags = merge(var.tags, {
    Environment              = var.env
    Name                     = local.cluster_name
    "karpenter.sh/discovery" = local.cluster_name
  })

  # Authentication
  aws_auth_users    = local.auth_users
  aws_auth_roles    = local.auth_roles
  aws_auth_accounts = var.accounts

  # Encryption Configuration
  eks_cluster_encryption_config = [
    {
      provider_key_arn = module.kms.eks_kms_key_arn
      resources        = ["secrets"]
    }
  ]

  # EKS Managed Node Groups
  eks_managed_node_groups = var.eks_node_group_internal

  # EKS Add-ons
  cluster_addons = {
    coredns = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
    }
    kube-proxy = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
    }
    vpc-cni = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
      service_account_role_arn    = module.vpc_cni_irsa.iam_role_arn
    }
    aws-ebs-csi-driver = {
      resolve_conflicts        = "OVERWRITE"
      addon_version            = var.ebs_csi_driver_version
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
    aws-efs-csi-driver = {
      resolve_conflicts        = "OVERWRITE"
      addon_version            = var.efs_csi_driver_version
      service_account_role_arn = module.efs_csi_irsa.iam_role_arn
    }
  }

  depends_on = [
    module.network,
    module.kms
  ]
}

############################
# IRSA Roles for EKS Add-ons
############################

# VPC CNI IRSA Role
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "${var.env}-VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.kubernetes.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = var.tags
}

# EBS CSI Driver IRSA Role
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "${var.env}-EBS-CSI-IRSA"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.kubernetes.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

# EFS CSI Driver IRSA Role
module "efs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "${var.env}-EFS-CSI-IRSA"
  attach_efs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.kubernetes.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

############################
# EKS Additional Roles
############################
module "eks_roles" {
  source     = "../../modules/eks-roles"
  cluster_id = module.kubernetes.cluster_id

  depends_on = [module.kubernetes]
}

############################
# Karpenter Configuration
############################

# Karpenter IAM roles
data "aws_iam_policy" "ssm_managed_instance" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "karpenter_ssm_policy" {
  role       = module.kubernetes.eks_managed_node_groups["internal"].iam_role_name
  policy_arn = data.aws_iam_policy.ssm_managed_instance.arn
}

resource "aws_iam_instance_profile" "karpenter" {
  name = "KarpenterNodeInstanceProfile-${local.cluster_name}"
  role = module.kubernetes.eks_managed_node_groups["internal"].iam_role_name

  tags = var.tags
}

############################
# ArgoCD (GitOps)
############################
module "argocd" {
  source = "../../modules/argocd-helm"

  cluster_id                  = module.kubernetes.cluster_id
  eks_cluster_ca_certificate  = base64decode(module.kubernetes.cluster_certificate_authority_data)
  argocd_helm_release_version = var.argocd_version

  argocd_helm_values = [
    templatefile("${path.module}/k8s-manifest/argocd-values.yaml", {
      dex_config_github_client_id = var.github_oauth_client_id
      private_domain              = "argocd.${var.domain_name}"
      enableLocalRedis            = true
      enable_admin_login          = true
      loggingLevel                = "info"
      redisExternalHost           = ""
    })
  ]

  depends_on = [module.kubernetes]
}

############################
# Additional Route53 and ACM for shared.pilotgab.com (Optional)
############################
module "route53_pilotgab" {
  source = "../../modules/aws_route53_zone_public"

  domain_name = "pilotgab.com"

  count = var.pilotgab_domain_enable ? 1 : 0
}

module "acm_pilotgab" {
  source = "../../modules/acm"

  zone_id                = try(module.route53_pilotgab[0].zone_id, "")
  domain_name            = "pilotgab.com"
  default_region         = var.region
  cloudfront_certificate = false
  validate_certificate   = true

  count = var.pilotgab_domain_enable ? 1 : 0

  depends_on = [module.route53_pilotgab]
}

############################
# Cross-Region Disaster Recovery
############################

# DR Region Provider (us-west-2)
provider "aws" {
  alias  = "dr_region"
  region = var.dr_region
}

# KMS Key for DR Region
resource "aws_kms_key" "dr_region" {
  provider = aws.dr_region

  description             = "KMS key for disaster recovery in ${var.dr_region}"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(var.tags, {
    Name        = "${var.env}-dr-kms-key"
    Environment = var.env
    Region      = var.dr_region
    Purpose     = "DisasterRecovery"
  })
}

resource "aws_kms_alias" "dr_region" {
  provider = aws.dr_region

  name          = "alias/${var.env}-dr-key"
  target_key_id = aws_kms_key.dr_region.key_id
}

# RDS Automated Backup Replication to DR Region
resource "aws_db_instance_automated_backups_replication" "replica" {
  provider = aws.dr_region

  source_db_instance_arn = module.data.rds_arn
  retention_period       = 35
  kms_key_id             = aws_kms_key.dr_region.arn

  depends_on = [
    module.data,
    aws_kms_key.dr_region
  ]
}

# S3 Bucket for DR Region Backups
resource "aws_s3_bucket" "dr_backups" {
  provider = aws.dr_region

  bucket = "${var.env}-dr-backups-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name        = "${var.env}-dr-backups"
    Environment = var.env
    Region      = var.dr_region
    Purpose     = "DisasterRecovery"
  })
}

# Enable versioning on DR backup bucket
resource "aws_s3_bucket_versioning" "dr_backups" {
  provider = aws.dr_region

  bucket = aws_s3_bucket.dr_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption on DR backup bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "dr_backups" {
  provider = aws.dr_region

  bucket = aws_s3_bucket.dr_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.dr_region.arn
    }
    bucket_key_enabled = true
  }
}

# Block public access on DR backup bucket
resource "aws_s3_bucket_public_access_block" "dr_backups" {
  provider = aws.dr_region

  bucket = aws_s3_bucket.dr_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for DR backup bucket
resource "aws_s3_bucket_lifecycle_configuration" "dr_backups" {
  provider = aws.dr_region

  bucket = aws_s3_bucket.dr_backups.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    expiration {
      days = 365
    }
  }
}

# IAM Role for S3 Replication
resource "aws_iam_role" "replication" {
  name = "${var.env}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
    }]
  })

  tags = merge(var.tags, {
    Name        = "${var.env}-s3-replication-role"
    Environment = var.env
    Purpose     = "S3CrossRegionReplication"
  })
}

# IAM Policy for S3 Replication
resource "aws_iam_role_policy" "replication" {
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          module.data.backup_bucket_arn
        ]
      },
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect = "Allow"
        Resource = [
          "${module.data.backup_bucket_arn}/*"
        ]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.dr_backups.arn}/*"
        ]
      },
      {
        Action = [
          "kms:Decrypt"
        ]
        Effect = "Allow"
        Resource = [
          module.kms.s3_kms_key_arn
        ]
        Condition = {
          StringLike = {
            "kms:ViaService" : "s3.${var.region}.amazonaws.com"
          }
        }
      },
      {
        Action = [
          "kms:Encrypt"
        ]
        Effect = "Allow"
        Resource = [
          aws_kms_key.dr_region.arn
        ]
        Condition = {
          StringLike = {
            "kms:ViaService" : "s3.${var.dr_region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Enable versioning on primary backup bucket (required for replication)
resource "aws_s3_bucket_versioning" "primary_backups" {
  bucket = module.data.backup_bucket_name

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Cross-Region Replication Configuration
resource "aws_s3_bucket_replication_configuration" "backup" {
  bucket = module.data.backup_bucket_name
  role   = aws_iam_role.replication.arn

  rule {
    id     = "replicate-to-dr"
    status = "Enabled"

    # Replicate all objects
    filter {}

    destination {
      bucket        = aws_s3_bucket.dr_backups.arn
      storage_class = "STANDARD_IA"

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.dr_region.arn
      }

      metrics {
        status = "Enabled"
        event_threshold {
          minutes = 15
        }
      }

      replication_time {
        status = "Enabled"
        time {
          minutes = 15
        }
      }
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.primary_backups,
    aws_s3_bucket.dr_backups,
    aws_iam_role_policy.replication
  ]
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
