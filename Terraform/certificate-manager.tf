# 1. Cert-Manager (Helm se install hoga)
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "1.20.2"
  namespace        = "cert-manager"
  create_namespace = true
  timeout          = 600

  values = [<<-EOT
    crds:
      enabled: true
    nodeSelector:
      role: system
    tolerations:
      - key: "CriticalAddonsOnly"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
  EOT
  ]
  depends_on = [module.eks]
}
# 2. ClusterIssuer
resource "kubectl_manifest" "letsencrypt_issuer" {
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-duckdns
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: muhammadali792@gmail.com
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
  depends_on = [kubectl_manifest.cert_manager_webhook_duckdns]
}
