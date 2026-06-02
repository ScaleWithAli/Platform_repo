# ─────────────────────────────────────────────
# Custom Policies
# ─────────────────────────────────────────────

resource "aws_iam_policy" "rds_access" {
  name        = "ecommerce-rds-access"
  description = "RDS access for auth and product services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["rds-db:connect"]
      Resource = aws_db_instance.postgres.arn
    }]
  })
}

resource "aws_iam_policy" "redis_access" {
  name        = "ecommerce-redis-access"
  description = "Redis access for notif service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["elasticache:*"]
      Resource = aws_elasticache_cluster.redis.arn
    }]
  })
}

resource "aws_iam_policy" "rds_redis_access" {
  name        = "ecommerce-rds-redis-access"
  description = "RDS + Redis access for order service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["rds-db:connect"]
        Resource = aws_db_instance.postgres.arn
      },
      {
        Effect   = "Allow"
        Action   = ["elasticache:*"]
        Resource = aws_elasticache_cluster.redis.arn
      }
    ]
  })
}

# ─────────────────────────────────────────────
# IAM Roles — IRSA
# ─────────────────────────────────────────────

locals {
  microservices_irsa = {
    auth-service = {
      namespace       = "ecommerce"
      service_account = "auth-service-sa"
      policy_arn      = aws_iam_policy.rds_access.arn
    }
    product-service = {
      namespace       = "ecommerce"
      service_account = "product-service-sa"
      policy_arn      = aws_iam_policy.rds_access.arn
    }
    order-service = {
      namespace       = "ecommerce"
      service_account = "order-service-sa"
      policy_arn      = aws_iam_policy.rds_redis_access.arn
    }
    notif-service = {
      namespace       = "ecommerce"
      service_account = "notif-service-sa"
      policy_arn      = aws_iam_policy.redis_access.arn
    }
  }
}

resource "aws_iam_role" "microservices" {
  for_each = local.microservices_irsa
  name     = "ecommerce-${each.key}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${aws_iam_openid_connect_provider.eks.url}:sub" = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
        }
      }
    }]
  })

  tags = local.common_tags
}

# ─────────────────────────────────────────────
# Policy Attachment
# ─────────────────────────────────────────────

resource "aws_iam_role_policy_attachment" "microservices" {
  for_each   = local.microservices_irsa
  role       = aws_iam_role.microservices[each.key].name
  policy_arn = each.value.policy_arn
}

# ─────────────────────────────────────────────
# Outputs — K8s ServiceAccount mein use honge
# ─────────────────────────────────────────────

output "microservices_role_arns" {
  description = "IAM Role ARNs for each microservice"
  value = {
    for k, v in aws_iam_role.microservices : k => v.arn
  }
}
