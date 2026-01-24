# Production Environment Outputs

############################
# EKS Cluster Outputs
############################
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.kubernetes.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.kubernetes.cluster_arn
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.kubernetes.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.kubernetes.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  value       = module.kubernetes.oidc_provider_arn
}

############################
# Network Outputs
############################
output "workload_vpc_id" {
  description = "Workload VPC ID"
  value       = module.network.workload_vpc_id
}

output "egress_vpc_id" {
  description = "Egress VPC ID"
  value       = module.network.egress_vpc_id
}

output "workload_private_subnets" {
  description = "Workload private subnet IDs"
  value       = module.network.workload_private_subnets
}

############################
# Database Outputs
############################
output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.data.rds_endpoint
  sensitive   = true
}

output "rds_arn" {
  description = "RDS ARN"
  value       = module.data.rds_arn
}

############################
# EKS Backup Outputs
############################
output "eks_backup_velero_bucket_name" {
  description = "Name of the S3 bucket for Velero backups"
  value       = module.eks_backup.velero_bucket_name
}

output "eks_backup_velero_bucket_arn" {
  description = "ARN of the S3 bucket for Velero backups"
  value       = module.eks_backup.velero_bucket_arn
}

output "eks_backup_velero_iam_role_arn" {
  description = "ARN of the IAM role for Velero"
  value       = module.eks_backup.velero_iam_role_arn
}

output "eks_backup_etcd_bucket_name" {
  description = "Name of the S3 bucket for ETCD backups"
  value       = module.eks_backup.etcd_backup_bucket_name
}

output "eks_backup_etcd_bucket_arn" {
  description = "ARN of the S3 bucket for ETCD backups"
  value       = module.eks_backup.etcd_backup_bucket_arn
}

output "eks_backup_ebs_snapshot_lambda_role_arn" {
  description = "ARN of the IAM role for EBS snapshot Lambda"
  value       = module.eks_backup.ebs_snapshot_lambda_role_arn
}

output "eks_backup_log_group_name" {
  description = "Name of the CloudWatch log group for backup operations"
  value       = module.eks_backup.backup_log_group_name
}

output "eks_backup_failure_alarm_arn" {
  description = "ARN of the CloudWatch alarm for backup failures"
  value       = module.eks_backup.backup_failure_alarm_arn
}

############################
# Disaster Recovery Outputs
############################
output "dr_backup_bucket_name" {
  description = "Name of the disaster recovery backup bucket"
  value       = aws_s3_bucket.dr_backups.bucket
}

output "dr_backup_bucket_arn" {
  description = "ARN of the disaster recovery backup bucket"
  value       = aws_s3_bucket.dr_backups.arn
}

output "dr_kms_key_arn" {
  description = "ARN of the KMS key in the DR region"
  value       = aws_kms_key.dr_region.arn
}

############################
# Security Outputs
############################
output "kms_eks_key_arn" {
  description = "ARN of the KMS key for EKS encryption"
  value       = module.kms.eks_kms_key_arn
}

############################
# ArgoCD Outputs
############################
output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = "argocd"
}

############################
# OpenSearch Outputs (for Jaeger Tracing)
############################
output "opensearch_domain_arn" {
  description = "ARN of the OpenSearch domain"
  value       = module.opensearch.opensearch_domain_arn
}

output "opensearch_domain_name" {
  description = "Name of the OpenSearch domain"
  value       = module.opensearch.opensearch_domain_name
}

output "opensearch_endpoint" {
  description = "OpenSearch domain endpoint"
  value       = module.opensearch.opensearch_endpoint
}

output "jaeger_elasticsearch_role_arn" {
  description = "ARN of the IAM role for Jaeger to access OpenSearch"
  value       = module.opensearch.jaeger_elasticsearch_role_arn
}

output "jaeger_helm_values" {
  description = "Helm values for Jaeger deployment"
  value       = module.opensearch.jaeger_helm_values
  sensitive   = true
}

############################
# Route53 Outputs
############################
output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.primary.zone_id
}

output "route53_zone_name" {
  description = "Route53 hosted zone name"
  value       = aws_route53_zone.primary.name
}
