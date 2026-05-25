module "eks_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.23.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # 1. AWS LOAD BALANCER CONTROLLER
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    values = [yamlencode({
      tolerations  = [{ key = "CriticalAddonsOnly", operator = "Equal", value = "true", effect = "NoSchedule" }]
      nodeSelector = { role = "system" }
    })]
  }

  # 2. NGINX INGRESS
  enable_ingress_nginx = true
  ingress_nginx = {
    values = [yamlencode({
      controller = {
        replicaCount = 2
        tolerations  = [{ key = "CriticalAddonsOnly", operator = "Equal", value = "true", effect = "NoSchedule" }]
        nodeSelector = { role = "system" }
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"               = "external"
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

  # 6. METRICS SERVER
  enable_metrics_server = true
  metrics_server = {
    values = [yamlencode({
      tolerations  = [{ key = "CriticalAddonsOnly", operator = "Equal", value = "true", effect = "NoSchedule" }]
      nodeSelector = { role = "system" }
    })]
  }

  # 7. EXTERNAL SECRETS
  enable_external_secrets = true
  external_secrets = {
    values = [yamlencode({
      tolerations  = [{ key = "CriticalAddonsOnly", operator = "Equal", value = "true", effect = "NoSchedule" }]
      nodeSelector = { role = "system" }
    })]
  }

  depends_on = [module.eks]
  tags       = local.common_tags
}
