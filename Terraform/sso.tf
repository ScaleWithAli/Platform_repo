# ─────────────────────────────────────────────
# 1. SSO Instance Data
# ─────────────────────────────────────────────
data "aws_ssoadmin_instances" "main" {}

# ─────────────────────────────────────────────
# 2. ArgoCD SSO Application
# ─────────────────────────────────────────────
resource "aws_ssoadmin_application" "argocd" {
  name                     = "argocd"
  application_provider_arn = "arn:aws:sso::aws:applicationProvider/custom"
  instance_arn             = tolist(data.aws_ssoadmin_instances.main.arns)[0]

  portal_options {
    sign_in_options {
      application_url = "https://argocd.cloudaura.online"
      origin          = "APPLICATION"
    }
    visibility = "ENABLED"
  }

  status = "ENABLED"
}

# ─────────────────────────────────────────────
# 3. Grafana SSO Application
# ─────────────────────────────────────────────
resource "aws_ssoadmin_application" "grafana" {
  name                     = "grafana"
  application_provider_arn = "arn:aws:sso::aws:applicationProvider/custom"
  instance_arn             = tolist(data.aws_ssoadmin_instances.main.arns)[0]

  portal_options {
    sign_in_options {
      application_url = "https://grafana.cloudaura.online"
      origin          = "APPLICATION"
    }
    visibility = "ENABLED"
  }

  status = "ENABLED"
}

# ─────────────────────────────────────────────
# 4. ArgoCD OIDC Secret
# ─────────────────────────────────────────────
resource "aws_secretsmanager_secret" "argocd_oidc" {
  name                    = "argocd/oidc-secret"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "argocd_oidc" {
  secret_id     = aws_secretsmanager_secret.argocd_oidc.id
  secret_string = jsonencode({
    oidc_client_secret = aws_ssoadmin_application.argocd.application_arn
  })
}

# ─────────────────────────────────────────────
# 5. Grafana OIDC Secret
# ─────────────────────────────────────────────
resource "aws_secretsmanager_secret" "grafana_oidc" {
  name                    = "grafana/oidc-secret"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "grafana_oidc" {
  secret_id     = aws_secretsmanager_secret.grafana_oidc.id
  secret_string = jsonencode({
    oidc_client_secret = aws_ssoadmin_application.grafana.application_arn
  })
}
