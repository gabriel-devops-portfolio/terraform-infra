resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name        = "public-zone-${var.domain_name}"
    ManagedBy   = "terraform"
    Environment = "production"
  }
}
