output "zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Route53 name servers"
  value       = aws_route53_zone.main.name_servers
}

output "domain_name" {
  description = "Domain name"
  value       = var.domain_name
}

output "arn" {
  description = "Route53 zone ARN"
  value       = aws_route53_zone.main.arn
}

output "zone_name" {
  description = "Route53 zone name"
  value       = aws_route53_zone.main.name
}
