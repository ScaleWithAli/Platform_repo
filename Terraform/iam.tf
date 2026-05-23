resource "aws_iam_role" "addon_roles" {
  for_each = var.eks_addons_security_config

  name = "${module.eks.cluster_name}-${each.key}-pod-identity"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "addon_roles" {
  for_each   = var.eks_addons_security_config
  role       = aws_iam_role.addon_roles[each.key].name
  policy_arn = each.value.policy_arn
}

resource "aws_eks_pod_identity_association" "addon_associations" {
  for_each        = var.eks_addons_security_config
  cluster_name    = module.eks.cluster_name
  namespace       = each.value.namespace
  service_account = each.value.service_account
  role_arn        = aws_iam_role.addon_roles[each.key].arn
} 
 
