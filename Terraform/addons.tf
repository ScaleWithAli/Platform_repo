module "eks_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.23.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # EKS Managed Addons
  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent              = true
      configuration_values = jsonencode({
        controller = {
          nodeSelector = local.system_scheduling.nodeSelector
          tolerations  = local.system_scheduling.tolerations
        }
        node = {
          nodeSelector = local.system_scheduling.nodeSelector
          tolerations  = local.system_scheduling.tolerations
        }
      })
    }
  }

  # LB Controller
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    values = [yamlencode({
      tolerations  = local.system_scheduling.tolerations
      nodeSelector = local.system_scheduling.nodeSelector
    })]
  }

  # NGINX Ingress
  enable_ingress_nginx = true
  ingress_nginx = {
    values = [yamlencode({
      controller = {
        replicaCount = 2
        config = {
         "force-ssl-redirect"    = "true"
         "use-forwarded-headers" = "true"
        }
        tolerations  = local.infra_scheduling.tolerations
        nodeSelector = local.infra_scheduling.nodeSelector
        admissionWebhooks = {
          patch = {
            tolerations  = local.infra_scheduling.tolerations
            nodeSelector = local.infra_scheduling.nodeSelector
          }
        }
        defaultBackend = {
          tolerations  = local.infra_scheduling.tolerations
          nodeSelector = local.infra_scheduling.nodeSelector
        }
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"                 = "external"
            "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"      = "ip"
            "service.beta.kubernetes.io/aws-load-balancer-scheme"               = "internet-facing"
            "service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol" = "HTTP"
            "service.beta.kubernetes.io/aws-load-balancer-healthcheck-port"     = "80"
            "service.beta.kubernetes.io/aws-load-balancer-healthcheck-path"     = "/healthz"
          }
        }
      }
    })]
  }

  # Metrics Server
  enable_metrics_server = true
  metrics_server = {
    values = [yamlencode({
      tolerations  = local.system_scheduling.tolerations
      nodeSelector = local.system_scheduling.nodeSelector
    })]
  }

  # External Secrets
  enable_external_secrets = true
  external_secrets = {
    values = [yamlencode({
      tolerations    = local.infra_scheduling.tolerations
      nodeSelector   = local.infra_scheduling.nodeSelector
      webhook = {
        tolerations  = local.infra_scheduling.tolerations
        nodeSelector = local.infra_scheduling.nodeSelector
      }
      certController = {
        tolerations  = local.infra_scheduling.tolerations
        nodeSelector = local.infra_scheduling.nodeSelector
      }
    })]
  }

  depends_on = [module.eks]
  tags       = local.common_tags
}
