resource "helm_release" "argo_cd" {
  name             = "argo-cd"
  chart            = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  namespace        = "argocd"
  create_namespace = true
  values           = [yamlencode(local.app_values.argocd)]
  depends_on       = [module.eks_addons]
}

resource "helm_release" "argo_rollouts" {
  name       = "argo-rollouts"
  chart      = "argo-rollouts"
  repository = "https://argoproj.github.io/argo-helm"
  namespace  = "argocd"
  values     = [yamlencode(local.app_values.argo_rollouts)]
  depends_on = [helm_release.argo_cd]
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  chart            = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  namespace        = "kube-prometheus-stack"
  create_namespace = true
  values           = [yamlencode(local.app_values.prometheus)]
  depends_on       = [module.eks_addons]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.17.2"
  namespace        = "cert-manager"
  create_namespace = true
  timeout          = 600

  values = [yamlencode({
    crds = { enabled = true }

    tolerations  = local.infra_scheduling.tolerations
    nodeSelector = local.infra_scheduling.nodeSelector
    cainjector = {
      tolerations  = local.infra_scheduling.tolerations
      nodeSelector = local.infra_scheduling.nodeSelector
    }
    startupapicheck = {
      nodeSelector = local.infra_scheduling.nodeSelector
      tolerations  = local.infra_scheduling.tolerations
    }
    webhook = {
      tolerations  = local.infra_scheduling.tolerations
      nodeSelector = local.infra_scheduling.nodeSelector
    }
  })]

  depends_on = [module.eks, module.eks_addons]
}
resource "kubectl_manifest" "cluster_issuer" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: m.ali.hassan.devops@gmail.com
        privateKeySecretRef:
          name: letsencrypt-prod
        solvers:
        - http01:
            ingress:
              class: nginx
  YAML

  depends_on = [helm_release.cert_manager, module.eks_addons]
}

resource "helm_release" "argocd_image_updater" {
  name             = "argocd-image-updater"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-image-updater"
  namespace        = "argocd"
  create_namespace = false

  values = [yamlencode({
    serviceAccount = {
      create = true
      name   = "argocd-image-updater-sa"
    }
    tolerations  = local.infra_scheduling.tolerations
    nodeSelector = local.infra_scheduling.nodeSelector
    config = {
      registries = [{
        name       = "ECR"
        api_url    = "https://${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
        prefix      = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
        credentials = "ext:/scripts/ecr-login.sh"
        credsexpire = "12h"
        ping        = true
        default     = true
      }]
      gitCredentials = [{
        url        = "https://github.com/muhammadali792"
        secretName = "argocd-image-updater-git-creds"
      }]
    }

    # Industry Standard: Auth script via Helm values
    authScripts = {
      enabled = true
      scripts = {
        "ecr-login.sh" = <<-EOF
        #!/bin/sh
        # ECR requires username 'AWS' and the password as the token
        TOKEN=$(aws ecr --region ${var.aws_region} get-login-password)
        echo "AWS:$TOKEN"
        EOF
      }
    }
  })]

  depends_on = [
    helm_release.argo_cd,
    aws_eks_pod_identity_association.addon_associations,
  ]
}
resource "helm_release" "istio_base" {
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  namespace        = "istio-system"
  create_namespace = true
  depends_on       = [module.eks_addons]
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  namespace  = "istio-system"
  values = [yamlencode({
    meshConfig = {
      defaultConfig = {
        holdApplicationUntilProxyStarts = true
      }
    }
    tolerations  = local.infra_scheduling.tolerations
    nodeSelector = local.infra_scheduling.nodeSelector
  })]
  depends_on = [helm_release.istio_base]
}
