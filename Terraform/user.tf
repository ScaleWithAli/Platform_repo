resource "aws_iam_user" "cluster_admin" {
  name = "ALi-The-Warrior"
  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_user_policy" "cluster_admin_eks" {
  name = "cluster-admin-eks-policy"
  user = aws_iam_user.cluster_admin.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi",
          "eks:ListNodegroups",
          "eks:DescribeNodegroup",
          "eks:ListAddons",
          "eks:DescribeAddon",
          "eks:ListUpdates",
          "eks:DescribeUpdate"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_eks_access_entry" "cluster_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_user.cluster_admin.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "cluster_admin" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_user.cluster_admin.arn

  access_scope {
    type = "cluster"
  }
}
