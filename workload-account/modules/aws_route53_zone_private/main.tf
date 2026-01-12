

resource "aws_route53_zone" "main" {
  name = var.domain_name
  vpc {
    vpc_id = var.vpc_id
  }

}

output "zone_id" {
  value = aws_route53_zone.main.zone_id
}

output "name_servers" {
  value = aws_route53_zone.main.name_servers
}