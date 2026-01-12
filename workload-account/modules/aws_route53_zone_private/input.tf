variable "domain_name" {
  description = "The desired domain's name"
  default     = ""
}

variable "vpc_id" {
  description = "Configuration block(s) specifying VPC(s) to associate with a private hosted zone"
  default     = ""
}
