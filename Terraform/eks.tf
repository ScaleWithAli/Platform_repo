module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  authentication_mode = "API"

  # Module ko bolein ke CloudWatch log group pehle se hai, naya na banaye
  create_cloudwatch_log_group = false

  # Module ko bolein ke KMS key aur alias bhi naya na banaye, default handle kare
  create_kms_key              = false
  cluster_encryption_config   = {}

  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    
    aws-ebs-csi-driver = {
      most_recent    = true
      before_compute = false

      configuration_values = jsonencode({
        controller = {
          tolerations = [
            {
              key      = "CriticalAddonsOnly"
              operator = "Exists"
              effect   = "NoSchedule"
            }
          ]
          nodeSelector = {
            role = "system" # 👈 Controller Deployment sirf system nodes par chalegi
          }
        }
        node = {
          tolerations = [
            {
              key      = "CriticalAddonsOnly"
              operator = "Exists"
              effect   = "NoSchedule"
            }
          ]
          # 🟢 Node DaemonSet pure cluster (Karpenter + System) par chalega, isliye selector nahi hai
        }
      })
    }

    eks-pod-identity-agent = {
      most_recent = true
      configuration_values = jsonencode({
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
            effect   = "NoSchedule"
          }
        ]
        # 🟢 Pod Identity DaemonSet pure cluster par chalega, isliye selector nahi hai
      })
    }
  }

  eks_managed_node_groups = {
    system = {
      node_group_name = "${var.cluster_name}-system"
      instance_types  = ["t3.small"]
      capacity_type   = "ON_DEMAND"

      min_size     = 1
      max_size     = 3
      desired_size = 2

      additional_security_group_ids = [aws_security_group.additional_node_sg.id]

      labels = {
        role = "system"
      }

      taints = [{
        key    = "CriticalAddonsOnly"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  tags = {
    Environment              = var.environment
    ManagedBy                = "Terraform"
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# ─────────────────────────────────────────────
# EBS CSI Driver IAM — Pod Identity
# ─────────────────────────────────────────────

data "aws_iam_policy_document" "ebs_csi_pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_pod_identity" {
  name               = "${var.cluster_name}-ebs-csi-pod-identity-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_pod_identity_assume.json

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_pod_identity" {
  role       = aws_iam_role.ebs_csi_pod_identity.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi_pod_identity.arn

  depends_on = [module.eks]
}

# ─────────────────────────────────────────────
# Karpenter IAM — Pod Identity
# ─────────────────────────────────────────────

module "karpenter_iam" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name = module.eks.cluster_name

  enable_pod_identity             = true
  create_pod_identity_association = true

  create_node_iam_role = true
  create_access_entry  = false

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  depends_on = [module.eks]
}

# ─────────────────────────────────────────────
# Access Entry — Karpenter provisioned nodes
# ─────────────────────────────────────────────

resource "aws_eks_access_entry" "karpenter_nodes" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = module.karpenter_iam.node_iam_role_arn
  type              = "EC2_LINUX"
  kubernetes_groups = ["system:nodes"]
  user_name         = "system:node:{{EC2PrivateDNSName}}"

  depends_on = [module.eks, module.karpenter_iam]
}
