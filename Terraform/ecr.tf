locals {
  # Sirf service names ki list
  service_names = ["auth", "product", "order", "notif"]
}

# ECR Repositories
resource "aws_ecr_repository" "service_repos" {
  # List ko set mein convert kiya taake for_each kaam kare
  for_each = toset(local.service_names)

  # Har item ke saath '-repo' jod diya
  name                 = "${each.value}-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Lifecycle policy (Keep last 5 images)
resource "aws_ecr_lifecycle_policy" "repo_policy" {
  for_each   = aws_ecr_repository.service_repos
  repository = each.value.name
  
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 5 }
      action       = { type = "expire" }
    }]
  })
}

# Output
output "ecr_repository_urls" {
  value = { for k, repo in aws_ecr_repository.service_repos : k => repo.repository_url }
}
