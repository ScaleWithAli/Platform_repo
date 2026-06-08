locals {
  services = {
    auth    = { rds = true,  redis = false, needs_jwt = true }
    product = { rds = true,  redis = true,  needs_jwt = false }
    order   = { rds = true,  redis = true,  needs_jwt = true }
    notif   = { rds = false, redis = true,  needs_jwt = false }
  }
}

# ─────────────────────────────────────────────
# 1. Random Secrets
# ─────────────────────────────────────────────

# RDS admin access ke liye Master Password
resource "random_password" "master_db_pass" {
  length  = 24
  special = true
}

# Har service ke liye alag database password
resource "random_password" "service_db_pass" {
  for_each = { for k, v in local.services : k => v if v.rds }
  length   = 16
  special  = true
}

resource "random_password" "jwt_secret" {
  length  = 32
  special = true
}

resource "random_password" "redis_pass" {
  length  = 16
  special = true
}

# ─────────────────────────────────────────────
# 2. Security Group
# ─────────────────────────────────────────────

resource "aws_security_group" "db_sg" {
  name        = "main-db-sg"
  description = "Access for DB and Redis"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ─────────────────────────────────────────────
# 3. Subnet Groups
# ─────────────────────────────────────────────

resource "aws_db_subnet_group" "main" {
  name       = "main-db-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "main-redis-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

# ─────────────────────────────────────────────
# 4. Infrastructure
# ─────────────────────────────────────────────

resource "aws_db_instance" "main_db" {
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "postgres"
  username               = "admin_user"
  password               = random_password.master_db_pass.result
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  skip_final_snapshot    = true
}

resource "aws_elasticache_cluster" "main_redis" {
  cluster_id         = "main-redis"
  engine             = "redis"
  node_type          = "cache.t4g.micro"
  num_cache_nodes    = 1
  security_group_ids = [aws_security_group.db_sg.id]
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  port               = 6379
}

# ─────────────────────────────────────────────
# 5. Secrets Manager
# ─────────────────────────────────────────────

resource "aws_secretsmanager_secret" "service_secrets" {
  for_each                = local.services
  name                    = "${each.key}-service/secrets"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "secrets_val" {
  for_each  = local.services
  secret_id = aws_secretsmanager_secret.service_secrets[each.key].id

  secret_string = jsonencode(merge(
    local.services[each.key].needs_jwt ? { JWT_SECRET = random_password.jwt_secret.result } : {},
    local.services[each.key].rds ? { 
        DATABASE_URL = "postgresql://${each.key}_user:${random_password.service_db_pass[each.key].result}@${aws_db_instance.main_db.address}:5432/${each.key}_db" 
    } : {},
    local.services[each.key].redis ? { REDIS_URL = "redis://:${random_password.redis_pass.result}@${aws_elasticache_cluster.main_redis.cache_nodes[0].address}:6379" } : {}
  ))
}

# ─────────────────────────────────────────────
# 6. Database & User Auto-Creation
# ─────────────────────────────────────────────

resource "null_resource" "init_db" {
  depends_on = [aws_db_instance.main_db]
  for_each   = { for k, v in local.services : k => v if v.rds }

  provisioner "local-exec" {
    command = <<-EOT
      psql -h ${aws_db_instance.main_db.address} -U admin_user -d postgres \
        -c 'CREATE DATABASE ${each.key}_db;' \
        -c 'CREATE USER ${each.key}_user WITH PASSWORD ''${random_password.service_db_pass[each.key].result}'';' \
        -c 'GRANT ALL PRIVILEGES ON DATABASE ${each.key}_db TO ${each.key}_user;' || true
    EOT

    environment = {
      PGPASSWORD = random_password.master_db_pass.result
    }
  }
}
