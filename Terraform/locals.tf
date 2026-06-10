locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # ─────────────────────────────────────────────
  # Scheduling: SYSTEM nodes
  # ─────────────────────────────────────────────
  system_scheduling = {
    nodeSelector = { role = "system" }
    tolerations = [{
      key      = "CriticalAddonsOnly"
      operator = "Equal"
      value    = "true"
      effect   = "NoSchedule"
    }]
  }

  # ─────────────────────────────────────────────
  # Scheduling: INFRA nodes
  # ─────────────────────────────────────────────
  infra_scheduling = {
    nodeSelector = { role = "infra" }
    tolerations = [{
      key      = "InfraOnly"
      operator = "Equal"
      value    = "true"
      effect   = "NoSchedule"
    }]
  }

  # ─────────────────────────────────────────────
  # Helm values per tool
  # ─────────────────────────────────────────────
  app_values = {
    argocd = {
      global = {
        nodeSelector = { role = "infra" }
        tolerations = [{
          key      = "InfraOnly"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }]
      }
      server = {
        nodeSelector = local.infra_scheduling.nodeSelector
        tolerations  = local.infra_scheduling.tolerations
        metrics = {
          enabled = true
        }
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          hostname         = "argocd.cloudaura.online"
          tls              = true
          annotations = {
            "cert-manager.io/cluster-issuer"               = "letsencrypt-prod"
            "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
            "nginx.ingress.kubernetes.io/ssl-redirect"     = "true"
          }
        }
        config = {
          "oidc.config" = yamlencode({
            name         = "AWS SSO"
            issuer       = "https://identitycenter.amazonaws.com/ssooidc/${tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]}"
            clientID     = aws_ssoadmin_application.argocd.application_arn
            clientSecret = "$oidc.clientSecret"
            requestedScopes = ["openid", "profile", "email"]
            requestedIDTokenClaims = {
              groups = { essential = true }
            }
          })
        }
        rbacConfig = {
          "policy.default" = "role:readonly"
          "policy.csv"     = "g, DevOps, role:admin\ng, Developers, role:readonly"
        }
      }
      controller = {
        nodeSelector = local.infra_scheduling.nodeSelector
        tolerations  = local.infra_scheduling.tolerations
        metrics = {
          enabled = true
        }
      }
      repoServer = {
        nodeSelector = local.infra_scheduling.nodeSelector
        tolerations  = local.infra_scheduling.tolerations
        metrics = {
          enabled = true
        }
      }
      applicationSet = {
        nodeSelector = local.infra_scheduling.nodeSelector
        tolerations  = local.infra_scheduling.tolerations
      }
      hooks = {
        enabled      = true
        nodeSelector = local.infra_scheduling.nodeSelector
        tolerations  = local.infra_scheduling.tolerations
      }
      redis = {
        nodeSelector = local.infra_scheduling.nodeSelector
        tolerations  = local.infra_scheduling.tolerations
      }
    }

    argo_rollouts = {
      controller = {
        nodeSelector = local.infra_scheduling.nodeSelector
        tolerations  = local.infra_scheduling.tolerations
        metrics = {
          enabled      = true
          nodeSelector = local.infra_scheduling.nodeSelector
          tolerations  = local.infra_scheduling.tolerations
        }
      }
      dashboard = {
        nodeSelector = local.infra_scheduling.nodeSelector
        tolerations  = local.infra_scheduling.tolerations
      }
    }

    prometheus = {
      prometheus = {
        prometheusSpec = {
          nodeSelector = local.infra_scheduling.nodeSelector
          tolerations  = local.infra_scheduling.tolerations
        }
      }
      thanosRuler = {
        thanosRulerSpec = {
          nodeSelector = local.infra_scheduling.nodeSelector
          tolerations  = local.infra_scheduling.tolerations
        }
      }
      grafana = {
        nodeSelector = local.infra_scheduling.nodeSelector
        tolerations  = local.infra_scheduling.tolerations
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          hosts            = ["grafana.cloudaura.online"]
          tls = [{
            secretName = "grafana-tls"
            hosts      = ["grafana.cloudaura.online"]
          }]
          annotations = {
            "cert-manager.io/cluster-issuer"           = "letsencrypt-prod"
            "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
          }
        }
        grafana_ini = {
          auth_generic_oauth = {
            enabled             = true
            name                = "AWS SSO"
            client_id           = aws_ssoadmin_application.grafana.application_arn
            client_secret       = "$__secretsmanager:grafana/oidc-secret:oidc_client_secret"
            scopes              = "openid profile email"
            auth_url            = "https://identitycenter.amazonaws.com/ssooidc/${tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]}/authorize"
            token_url           = "https://identitycenter.amazonaws.com/ssooidc/${tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]}/token"
            api_url             = "https://identitycenter.amazonaws.com/ssooidc/${tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]}/userinfo"
            allow_sign_up       = true
            role_attribute_path = "contains(groups[*], 'DevOps') && 'Admin' || 'Viewer'"
          }
        }
      }
      kube-state-metrics = {
        enabled      = true
        nodeSelector = local.infra_scheduling.nodeSelector
        tolerations  = local.infra_scheduling.tolerations
      }
      prometheusNodeExporter = {
        nodeSelector = local.infra_scheduling.nodeSelector
        tolerations  = local.infra_scheduling.tolerations
      }
      alertmanager = {
        alertmanagerSpec = {
          nodeSelector = local.infra_scheduling.nodeSelector
          tolerations  = local.infra_scheduling.tolerations
        }
      }
      prometheusOperator = {
        nodeSelector = local.infra_scheduling.nodeSelector
        tolerations  = local.infra_scheduling.tolerations
        admissionWebhooks = {
          patch = {
            nodeSelector = local.infra_scheduling.nodeSelector
            tolerations  = local.infra_scheduling.tolerations
          }
        }
      }
    }
  }
}
