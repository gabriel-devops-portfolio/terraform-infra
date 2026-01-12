variable "domain_name" {}

variable "zone_id" {}

variable "wildcard_enable" {
  default = true
}

variable "cloudfront_certificate" {
  default = false
}

variable "cf_region" {
  default = "us-east-1"
}
variable "default_region" {
  default = "eu-west-1"
}
variable "extra_subject_alternative_names" {
  default = []
}
variable "validate_certificate" {
  default = true
}
