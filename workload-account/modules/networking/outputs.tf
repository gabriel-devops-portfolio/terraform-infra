output "workload_vpc_id" {
  description = "Workload VPC ID"
  value       = module.workload_vpc.vpc_id
}

output "workload_vpc_cidr" {
  description = "Workload VPC CIDR"
  value       = var.workload_vpc_cidr
}

output "workload_private_subnets" {
  description = "Workload private subnets"
  value       = module.workload_vpc.private_subnets
}

output "workload_database_subnets" {
  description = "Workload database subnets for RDS"
  value       = module.workload_vpc.database_subnets
}

output "egress_vpc_id" {
  description = "Egress VPC ID"
  value       = module.egress_vpc.vpc_id
}

output "egress_vpc_cidr" {
  description = "Egress VPC CIDR"
  value       = var.egress_vpc_cidr
}

output "egress_public_subnets" {
  description = "Egress public subnets"
  value       = module.egress_vpc.public_subnets
}

output "firewall_subnets" {
  description = "Firewall subnets"
  value       = var.firewall_subnets
}

output "tgw_subnets" {
  description = "Transit Gateway attachment subnets"
  value       = var.tgw_subnets
}

output "natgw_ids" {
  description = "NAT Gateway IDs"
  value       = module.egress_vpc.natgw_ids
}

output "tgw_id" {
  description = "Transit Gateway ID"
  value       = aws_ec2_transit_gateway.main.id
}

output "firewall_name" {
  description = "Network Firewall name"
  value       = aws_networkfirewall_firewall.egress.name
}

output "firewall_policy_arn" {
  description = "Network Firewall policy ARN"
  value       = aws_networkfirewall_firewall_policy.egress.arn
}

############################################
# VPC Endpoint IDs (for SCP enforcement)
############################################

output "vpce_secretsmanager_id" {
  description = "Secrets Manager VPC Endpoint ID"
  value       = aws_vpc_endpoint.secretsmanager.id
}

output "vpce_kms_id" {
  description = "KMS VPC Endpoint ID"
  value       = aws_vpc_endpoint.kms.id
}

output "vpce_s3_id" {
  description = "S3 Gateway VPC Endpoint ID"
  value       = aws_vpc_endpoint.s3.id
}

############################
# Transit Gateway Outputs
############################
output "tgw_inspection_route_table_id" {
  description = "Transit Gateway inspection route table ID"
  value       = aws_ec2_transit_gateway_route_table.inspection.id
}

output "egress_tgw_attachment_id" {
  description = "Egress VPC Transit Gateway attachment ID"
  value       = aws_ec2_transit_gateway_vpc_attachment.egress.id
}

output "workload_tgw_attachment_id" {
  description = "Workload VPC Transit Gateway attachment ID"
  value       = aws_ec2_transit_gateway_vpc_attachment.workload.id
}
