module "eks_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # =============================================================================
  # AWS LOAD BALANCER CONTROLLER — [DISABLED]
  # =============================================================================
  # enable_aws_load_balancer_controller = true

  # =============================================================================
  # NGINX INGRESS + NLB — [ACTIVE]
  # =============================================================================
  enable_ingress_nginx = true
  ingress_nginx = {
    values = [
      yamlencode({
        controller = {
          # Karpenter nodes par burden kam karne ke liye replicas 3 se 2 kar di hain
          replicaCount = 2

          topologySpreadConstraints = [
            {
              maxSkew           = 1
              topologyKey       = "topology.kubernetes.io/zone"
              whenUnsatisfiable = "DoNotSchedule"
              labelSelector = {
                matchLabels = {
                  "app.kubernetes.io/name" = "ingress-nginx"
                }
              }
            }
          ]

          resources = {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "200m", memory = "256Mi" }
          }

          service = {
            type                  = "LoadBalancer"
            externalTrafficPolicy = "Local"
            annotations = {
              "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
              "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
              "service.beta.kubernetes.io/aws-load-balancer-scheme"                                = "internet-facing"
              "service.beta.kubernetes.io/aws-load-balancer-health-check-path"                     = "/healthz"
              "service.beta.kubernetes.io/aws-load-balancer-health-check-port"                     = "10254"
              "service.beta.kubernetes.io/aws-load-balancer-health-check-protocol"                 = "HTTP"
              "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"                       = "ip"
            }
          }

          config = {
            use-forwarded-headers      = "true"
            compute-full-forwarded-for = "true"
          }
        }
      })
    ]
  }

  # =============================================================================
  # ARGOCD — [TEMPORARILY DISABLED VIA COMMENT]
  # =============================================================================
  enable_argocd = true
  argocd = {
    namespace = "argocd"
    values = [
      yamlencode({
        server = {
          extraArgs = []
          ingress = {
            enabled          = true
            ingressClassName = "nginx"
            hosts            = "argocd.${var.domain_name}"
            annotations = {
              "cert-manager.io/cluster-issuer"               = "letsencrypt-duckdns"
              "nginx.ingress.kubernetes.io/ssl-redirect"    = "true"
              "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
              "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
            }
            tls = [
              {
                secretName = "argocd-server-tls"
                hosts      = ["argocd.$${var.domain_name}"]
              }
            ]
          }
          metrics = {
            enabled        = false
            serviceMonitor = { enabled = false }
          }
        }
        controller = {
          metrics = {
            enabled        = false
            serviceMonitor = { enabled = false }
          }
        }
        repoServer = {
          metrics = {
            enabled        = false
            serviceMonitor = { enabled = false }
          }
        }
      })
    ]
  }

  # =============================================================================
  # METRICS SERVER — [DISABLED]
  # =============================================================================
  # enable_metrics_server = true

  # =============================================================================
  # EXTERNAL SECRETS — [DISABLED]
  # =============================================================================
  # enable_external_secrets = true

  # =============================================================================
  # PROMETHEUS + GRAFANA — [DISABLED]
  # =============================================================================
  # enable_kube_prometheus_stack = true

  # =============================================================================
  # STORAGE DRIVERS — [DISABLED]
  # =============================================================================
  # enable_aws_efs_csi_driver = true
  # enable_secrets_store_csi_driver = true

  depends_on = [module.eks]
  tags       = local.common_tags
}
