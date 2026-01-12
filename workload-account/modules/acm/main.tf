

data "aws_caller_identity" "current" {}
module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name = var.domain_name
  zone_id     = var.zone_id

  subject_alternative_names = local.subject_alternative_names

  validate_certificate = var.validate_certificate
  validation_method    = "DNS"
  wait_for_validation  = false

  tags = {
    Name = "${var.domain_name}"
  }
}
