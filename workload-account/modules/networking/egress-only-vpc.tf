module "egress_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.env}-egress-vpc"
  cidr = var.egress_vpc_cidr
  azs  = var.azs

  public_subnets = var.egress_public_subnets

  intra_subnets = concat(
    var.firewall_subnets,
    var.tgw_subnets
  )

  create_igw = true

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  enable_dns_support   = true
  enable_dns_hostnames = true

  ################################
  # Flow Logs (Enterprise)
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
  # Subnet Tags
  ################################
  public_subnet_tags = {
    "Network" = "Public"
    "Tier"    = "Egress"
  }

  intra_subnet_tags = {
    "Network" = "Inspection"
    "Tier"    = "Firewall-TGW"
  }

  ################################
  # Global Tags
  ################################
  tags = merge(var.tags, {
    VPC-Type    = "egress"
    Environment = var.env
  })
}

############################
# CRITICAL: IGW Route Table for Ingress Path
############################
resource "aws_route_table" "igw" {
  vpc_id = module.egress_vpc.vpc_id

  tags = {
    Name        = "${var.env}-igw-rt"
    Environment = var.env
    Purpose     = "ingress-inspection"
  }
}

# Route ingress traffic from IGW through firewall before reaching workloads
resource "aws_route" "igw_to_firewall" {
  for_each = local.firewall_endpoints

  route_table_id         = aws_route_table.igw.id
  destination_cidr_block = var.workload_vpc_cidr
  vpc_endpoint_id        = each.value
}

resource "aws_route_table_association" "igw" {
  gateway_id     = module.egress_vpc.igw_id
  route_table_id = aws_route_table.igw.id
}

############################
# Public Subnet Route Table → NAT via Firewall
############################
resource "aws_route" "public_to_firewall" {
  count = length(module.egress_vpc.public_route_table_ids)

  route_table_id         = module.egress_vpc.public_route_table_ids[count.index]
  destination_cidr_block = var.workload_vpc_cidr
  vpc_endpoint_id        = local.firewall_endpoints[var.azs[count.index]]

  depends_on = [aws_networkfirewall_firewall.egress]
}
