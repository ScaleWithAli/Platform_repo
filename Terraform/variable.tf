data "aws_caller_identity" "current" {}

variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "cluster_version" {
  type    = string
  default = "1.35"
}

variable "environment" {
  type    = string
  default = "staging"
}

variable "cluster_name" {
  type    = string
  default = "cloudaura-eks-cluster"
}

variable "domain_name" {
  type    = string
  default = ""
}

variable "availability_zones" {
  type    = list(string)
  default = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

