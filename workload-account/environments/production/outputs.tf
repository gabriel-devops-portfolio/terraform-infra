############################
# Networking Outputs
############################
output "workload_vpc_id" {
  description = "Workload VPC ID"
  value       = module.network.workload_vpc_id
}

output "workload_vpc_cidr" {
  description = "Workload VPC CIDR"
  value       = module.network.workload_vpc_cidr
}

output "workload_private_subnets" {
  description = "Workload private subnet IDs"
  value       = module.network.workload_private_subnets
}

output "egress_vpc_id" {
  description = "Egress VPC ID"
  value       = module.network.egress_vpc_id
}

output "transit_gateway_id" {
  description = "Transit Gateway ID"
  value       = module.network.tgw_id
}

output "network_firewall_name" {
  description = "Network Firewall name"
  value       = module.network.firewall_name
}

############################
# EKS Cluster Outputs
############################
output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = module.kubernetes.cluster_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = local.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.kubernetes.cluster_endpoint
  sensitive   = true
}

output "eks_cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = module.kubernetes.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  value       = module.kubernetes.oidc_provider_arn
}

output "eks_node_security_group_id" {
  description = "EKS node security group ID"
  value       = module.kubernetes.node_security_group_id
}

############################
# KMS Outputs
############################
output "eks_kms_key_arn" {
  description = "EKS KMS key ARN"
  value       = module.kms.eks_kms_key_arn
}

############################
# Route53 and ACM Outputs
############################
output "primary_zone_id" {
  description = "Primary Route53 zone ID"
  value       = aws_route53_zone.primary.zone_id
}

output "primary_zone_name_servers" {
  description = "Primary Route53 zone name servers"
  value       = aws_route53_zone.primary.name_servers
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate.eks_cert.arn
}

output "acm_certificate_status" {
  description = "ACM certificate validation status"
  value       = aws_acm_certificate.eks_cert.status
}

output "acm_certificate_domain_validation_options" {
  description = "ACM certificate domain validation options"
  value       = aws_acm_certificate.eks_cert.domain_validation_options
  sensitive   = true
}

############################
# ArgoCD Outputs
############################
output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = "argocd"
}

output "argocd_url" {
  description = "ArgoCD URL"
  value       = "https://argocd.${var.domain_name}"
}

############################
# Data Module Outputs
############################
output "backup_bucket_name" {
  description = "S3 backup bucket name"
  value       = module.data.backup_bucket_name
}

output "backup_bucket_arn" {
  description = "S3 backup bucket ARN"
  value       = module.data.backup_bucket_arn
}

############################
# RDS Outputs
############################
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.data.rds_endpoint
  sensitive   = true
}

output "rds_instance_id" {
  description = "RDS instance ID"
  value       = module.data.rds_instance_id
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.data.rds_database_name
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = module.data.rds_security_group_id
}

output "rds_arn" {
  description = "RDS instance ARN"
  value       = module.data.rds_arn
}

############################
# Disaster Recovery Outputs
############################
output "dr_region" {
  description = "Disaster recovery region"
  value       = var.dr_region
}

output "dr_kms_key_arn" {
  description = "DR region KMS key ARN"
  value       = aws_kms_key.dr_region.arn
}

output "dr_backup_bucket_name" {
  description = "DR region S3 backup bucket name"
  value       = aws_s3_bucket.dr_backups.id
}

output "dr_backup_bucket_arn" {
  description = "DR region S3 backup bucket ARN"
  value       = aws_s3_bucket.dr_backups.arn
}

output "dr_rds_backup_replication_id" {
  description = "RDS automated backup replication ID in DR region"
  value       = aws_db_instance_automated_backups_replication.replica.id
}

output "s3_replication_role_arn" {
  description = "S3 cross-region replication IAM role ARN"
  value       = aws_iam_role.replication.arn
}

output "dr_status" {
  description = "Disaster recovery configuration status"
  value = {
    enabled               = var.enable_dr_replication
    dr_region             = var.dr_region
    rds_backup_replicated = true
    s3_backup_replicated  = true
    retention_days        = 35
    rto_target            = "< 15 minutes"
    rpo_target            = "< 5 minutes"
  }
}
