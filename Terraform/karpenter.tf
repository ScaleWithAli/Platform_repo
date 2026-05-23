resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.0.6"

  # Industry Standard Template Loading
  values = [
    templatefile("${path.module}/templates/karpenter-values.yaml", {
      cluster_name     = var.cluster_name
      cluster_endpoint = module.eks.cluster_endpoint
      iam_role_arn     = module.karpenter_iam.iam_role_arn
    })
  ]

  depends_on = [module.eks, module.karpenter_iam]
}

resource "kubectl_manifest" "node_class" {
  yaml_body = templatefile("${path.module}/templates/ec2-node-class.yaml", {
    cluster_name       = var.cluster_name
    node_iam_role_name = module.karpenter_iam.node_iam_role_name
    environment        = var.environment
    cluster_version    = var.cluster_version
  })

  depends_on = [helm_release.karpenter]
}

resource "kubectl_manifest" "node_pool_general" {
  yaml_body = templatefile("${path.module}/templates/node-pool.yaml", {})

  depends_on = [kubectl_manifest.node_class]
}
