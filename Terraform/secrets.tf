locals {
  services = {
    auth    = { rds = true,  redis = false, needs_jwt = true }
    product = { rds = true,  redis = true,  needs_jwt = false }
    order   = { rds = true,  redis = true,  needs_jwt = true }
    notif   = { rds = false, redis = true,  needs_jwt = false }
  }
}

# 1. Random Secrets
resource "random_password" "db_pass" { length = 16 }
resource "random_password" "jwt_secret" { length = 32 }
resource "random_password" "redis_pass" { length = 16 }

# 2. Security Group (Firewall)
resource "aws_security_group" "db_sg" {
  name        = "main-db-sg"
  description = "Access for DB and Redis"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Infrastructure
resource "aws_db_instance" "main_db" {
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "main_db"
  username               = "postgres"
  password               = random_password.db_pass.result
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
}

resource "aws_elasticache_cluster" "main_redis" {
  cluster_id           = "main-redis"
  engine               = "redis"
  node_type            = "cache.t4g.micro"
  num_cache_nodes      = 1
  security_group_ids   = [aws_security_group.db_sg.id]
  port                 = 6379
}

# 4. Secrets Manager
resource "aws_secretsmanager_secret" "service_secrets" {
  for_each = local.services
  name     = "${each.key}-service/secrets"
}

resource "aws_secretsmanager_secret_version" "secrets_val" {
  for_each  = local.services
  secret_id = aws_secretsmanager_secret.service_secrets[each.key].id
  secret_string = jsonencode(merge(
    local.services[each.key].needs_jwt ? { JWT_SECRET = random_password.jwt_secret.result } : {},
    local.services[each.key].rds   ? { DATABASE_URL = "postgresql://postgres:${random_password.db_pass.result}@${aws_db_instance.main_db.address}:5432/${each.key}_db" } : {},
    local.services[each.key].redis ? { REDIS_URL    = "redis://:${random_password.redis_pass.result}@${aws_elasticache_cluster.main_redis.cache_nodes[0].address}:6379" } : {}
  ))
}

# 5. Database Auto-Creation (Professional & Idempotent)
resource "null_resource" "init_db" {
  depends_on = [aws_db_instance.main_db]
  # Yahan filter apply kiya gaya hai
  for_each   = { for k, v in local.services : k => v if v.rds }

  provisioner "local-exec" {
    command = "psql -h ${aws_db_instance.main_db.address} -U postgres -d postgres -c 'CREATE DATABASE ${each.key}_db;' || true"
    
    environment = {
      PGPASSWORD = random_password.db_pass.result
    }
  }
}
