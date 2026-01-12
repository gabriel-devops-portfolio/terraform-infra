############################
# Transit Gateway
############################
resource "aws_ec2_transit_gateway" "main" {
  description = "Central inspection TGW"

  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
}

############################
# TGW Attachments
############################
resource "aws_ec2_transit_gateway_vpc_attachment" "workload" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = module.workload_vpc.vpc_id
  subnet_ids         = module.workload_vpc.private_subnets

  dns_support = "enable"

  tags = {
    Name = "workload-vpc-attachment"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "egress" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = module.egress_vpc.vpc_id
  subnet_ids         = slice(module.egress_vpc.intra_subnets, length(var.firewall_subnets), length(module.egress_vpc.intra_subnets))

  appliance_mode_support = "enable"
  dns_support            = "enable"

  tags = {
    Name = "egress-vpc-attachment"
  }
}

############################
# CRITICAL: Workload VPC Default Route → TGW
############################
resource "aws_route" "workload_to_tgw" {
  count = length(module.workload_vpc.private_route_table_ids)

  route_table_id         = module.workload_vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.workload]
}

############################
# TGW Subnet Route Tables → TGW
############################
resource "aws_route_table" "tgw_subnets" {
  vpc_id = module.egress_vpc.vpc_id

  tags = {
    Name        = "${var.env}-tgw-subnets-rt"
    Environment = var.env
    Purpose     = "tgw-attachment"
  }
}

# TGW subnets route back to firewall for return traffic
resource "aws_route" "tgw_subnets_to_firewall" {
  for_each = local.firewall_endpoints

  route_table_id         = aws_route_table.tgw_subnets.id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = each.value

  depends_on = [aws_networkfirewall_firewall.egress]
}

resource "aws_route_table_association" "tgw_subnets" {
  count = length(var.tgw_subnets)

  subnet_id      = module.egress_vpc.intra_subnets[length(var.firewall_subnets) + count.index]
  route_table_id = aws_route_table.tgw_subnets.id
}

############################
# TGW Route Table (Inspection)
############################
resource "aws_ec2_transit_gateway_route_table" "inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name = "inspection-rt"
  }
}

############################
# TGW Routes → Firewall Endpoints
############################
resource "aws_route" "tgw_to_firewall" {
  for_each = local.firewall_endpoints

  route_table_id         = module.egress_vpc.intra_route_table_ids[index(var.azs, each.key)]
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = each.value

  depends_on = [aws_networkfirewall_firewall.egress]
}

resource "aws_ec2_transit_gateway_route_table_association" "workload" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}

resource "aws_ec2_transit_gateway_route_table_association" "egress" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}

resource "aws_ec2_transit_gateway_route" "default_to_egress" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id

  lifecycle {
    ignore_changes = all
  }
}

############################
# TGW Routes (Baseline)
############################

# Return path → workload VPC (ALWAYS present)
resource "aws_ec2_transit_gateway_route" "return_to_workload" {
  destination_cidr_block         = module.workload_vpc.vpc_cidr
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload.id
}
