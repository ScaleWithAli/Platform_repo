data "kubernetes_service" "nginx_ingress" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [module.eks_addons]
}

data "aws_lb" "nginx" {
  tags = {
    "elbv2.k8s.aws/cluster"    = module.eks.cluster_name
    "service.k8s.aws/resource" = "LoadBalancer"
  }
  depends_on = [module.eks_addons]
}

resource "aws_route53_zone" "main" {
  name = var.domain_name
  tags = local.common_tags
}

resource "aws_route53_record" "main" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname
    zone_id                = data.aws_lb.nginx.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "wildcard" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "*.${var.domain_name}"
  type    = "A"
  alias {
    name                   = data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname
    zone_id                = data.aws_lb.nginx.zone_id
    evaluate_target_health = true
  }
}
