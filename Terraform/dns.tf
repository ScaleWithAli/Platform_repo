/*
resource "aws_route53_zone" "main" {
  name = var.domain_name
  tags = local.common_tags
}

output "name_servers" {
  description = "Hostinger mein ye 4 NS records add karo"
  value       = aws_route53_zone.main.name_servers
}
*/
