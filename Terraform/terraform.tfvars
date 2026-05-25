eks_addons_security_config = {
  aws-load-balancer-controller = {
    namespace       = "kube-system"
    service_account = "aws-load-balancer-controller"
    policy_arn      = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  }

  external-secrets = {
    namespace       = "kube-system"
    service_account = "external-secrets"
    policy_arn      = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
  }

  # Image Updater ki configuration
  argocd-image-updater = {
    namespace       = "argocd"
    service_account = "argocd-image-updater-sa"
    policy_arn      = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  }
}
