locals {
  service_names = ["auth", "product", "order", "notif", "frontend"]
}

resource "aws_ecr_repository" "service_repos" {
  for_each = toset(local.service_names)

  name                 = "${each.value}-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

output "ecr_repository_urls" {
  value = { for k, repo in aws_ecr_repository.service_repos : k => repo.repository_url }
}
