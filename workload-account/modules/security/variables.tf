variable "env" {
  description = "Environment name (prod, staging)"
  type        = string
}

variable "region" {
  description = "aws_region"
  type        = string
}

variable "tgw_route_table_id" {
  description = "Transit Gateway inspection route table ID"
  type        = string
}

variable "egress_attachment_id" {
  description = "Transit Gateway attachment ID for egress VPC"
  type        = string
}

variable "firewall_name" {
  description = "AWS Network Firewall name"
  type        = string
}

variable "enable_fail_close" {
  description = "Enable automated fail-close enforcement"
  type        = bool
  default     = true
}
