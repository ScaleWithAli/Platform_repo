module "eks_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # AWS LOAD BALANCER CONTROLLER
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    values = [yamlencode({
      tolerations = [{
        key      = "CriticalAddonsOnly"
        operator = "Equal"
        value    = "true"
        effect   = "NoSchedule"
      }]
      nodeSelector = { role = "system" }
    })]
  }

  # NGINX INGRESS
  enable_ingress_nginx = true
  ingress_nginx = {
    # Timeout, Atomic, aur Cleanup yahan 'helm_config' ke andar jayenge
    helm_config = {
      timeout         = 600
      atomic          = true
      cleanup_on_fail = true
    }
    values = [yamlencode({
      controller = {
        replicaCount = 2
        tolerations = [{
          key      = "CriticalAddonsOnly"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }]
        nodeSelector = { role = "system" }
        config = {
          "force-ssl-redirect" = "false"
          "ssl-redirect"       = "false"
        }
        service = {
          type = "NodePort"
          annotations = {
            #"service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "instance"
            "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
          }
        }
      }
      admissionWebhooks = {
        patch = {
          tolerations  = [{ key = "CriticalAddonsOnly", operator = "Equal", value = "true", effect = "NoSchedule" }]
          nodeSelector = { role = "system" }
        }
        createSecretJob = {
          tolerations  = [{ key = "CriticalAddonsOnly", operator = "Equal", value = "true", effect = "NoSchedule" }]
          nodeSelector = { role = "system" }
        }
        patchWebhookJob = {
          tolerations  = [{ key = "CriticalAddonsOnly", operator = "Equal", value = "true", effect = "NoSchedule" }]
          nodeSelector = { role = "system" }
        }
      }
    })]
  }
  # ArgoCD Addon
  enable_argocd = true
  argocd = {
    values = [yamlencode({
      server = {
        service = {
          # Jab tak load balancer issue hai, NodePort use karein
          type = "NodePort"
        }
      }
    })]
  }

  # CORE ADDONS
  enable_metrics_server   = true
  enable_external_secrets = true

  depends_on = [module.eks]
  tags       = local.common_tags
}
