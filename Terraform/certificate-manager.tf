resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.14.4"
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [module.eks]
}

resource "helm_release" "cert_manager_duckdns" {
  name       = "cert-manager-webhook-duckdns"
  repository = "https://ndom91.github.io/cert-manager-webhook-duckdns"
  chart      = "cert-manager-webhook-duckdns"
  version    = "v0.3.0"
  namespace  = "cert-manager"

  set {
    name  = "certManager.namespace"
    value = "cert-manager"
  }

  set {
    name  = "groupName"
    value = "acme.webhook.duckdns.org"
  }
  
  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "duckdns_secret" {
  yaml_body = <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: duckdns-token-secret
  namespace: cert-manager
type: Opaque
stringData:
  token: "896a3c54-360c-4a20-8d25-e421eeccf181"
YAML

  depends_on = [helm_release.cert_manager_duckdns]
}

resource "kubectl_manifest" "letsencrypt_issuer" {
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-duckdns
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: muhammadali792@github
    privateKeySecretRef:
      name: letsencrypt-account-key
    solvers:
    - dns01:
        webhook:
          groupName: acme.webhook.duckdns.org
          solverName: duckdns
          config:
            secretRef:
              name: duckdns-token-secret
              key: token
YAML

  depends_on = [kubectl_manifest.duckdns_secret]
}
