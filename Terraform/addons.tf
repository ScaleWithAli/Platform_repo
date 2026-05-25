module "eks_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # =============================================================================

  # =============================================================================
  # AWS LOAD BALANCER CONTROLLER
  # =============================================================================
  enable_aws_load_balancer_controller = true

  # =============================================================================
  # NGINX INGRESS + NLB
  # =============================================================================
  enable_ingress_nginx = true
  ingress_nginx = {
    values = [
      yamlencode({
        controller = {
          replicaCount = 2
          service = {
            type = "LoadBalancer"
            annotations = {
              "service.beta.kubernetes.io/aws-load-balancer-type"            = "nlb"
              "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
            }
          }
        }
      })
    ]
  }

  # =============================================================================
  # ARGOCD & CORE ADDONS
  # =============================================================================
  enable_argocd = true
  argocd = {
    namespace = "argocd"
    values = [
      yamlencode({
        server = {
          ingress = {
            enabled          = true
            ingressClassName = "nginx"
            hosts            = ["argocd.${var.domain_name}"]
            annotations      = { "cert-manager.io/cluster-issuer" = "letsencrypt-prod" }
          }
        }
      })
    ]
  }

  enable_metrics_server   = true
  enable_external_secrets = true

  depends_on = [module.eks]
  tags       = local.common_tags
}
