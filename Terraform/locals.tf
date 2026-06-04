locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # ─────────────────────────────────────────────
  # Scheduling: SYSTEM nodes
  # Sirf AWS core components ke liye
  # ─────────────────────────────────────────────
  system_scheduling = {
    nodeSelector = { role = "system" }
    tolerations  = [{
      key      = "CriticalAddonsOnly"
      operator = "Equal"
      value    = "true"
      effect   = "NoSchedule"
    }]
  }

  # ─────────────────────────────────────────────
  # Scheduling: INFRA nodes
  # Karpenter, ArgoCD, Prometheus, cert-manager
  # ─────────────────────────────────────────────
  infra_scheduling = {
    nodeSelector = { role = "infra" }
    tolerations  = [{
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
      server = {
        nodeSelector = local.infra_scheduling.nodeSelector
        tolerations  = local.infra_scheduling.tolerations
      }
      controller = {
        nodeSelector = local.infra_scheduling.nodeSelector
        tolerations  = local.infra_scheduling.tolerations
      }
      repoServer = {
        nodeSelector = local.infra_scheduling.nodeSelector
        tolerations  = local.infra_scheduling.tolerations
      }
      applicationSet = {
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
      }
    }

    prometheus = {
      prometheus = {
        prometheusSpec = {
          nodeSelector = local.infra_scheduling.nodeSelector
          tolerations  = local.infra_scheduling.tolerations
        }
      }
      grafana = {
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
        #admissionWebhooks 
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
