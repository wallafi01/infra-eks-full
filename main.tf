terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    } 
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}


# Modulo de Vpc
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${terraform.workspace}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  enable_nat_gateway = true
  enable_vpn_gateway = false
  map_public_ip_on_launch = true

  tags = {
    Environment = terraform.workspace
  }
}


# Module Cluster e Node
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "cluster-${terraform.workspace}"
  cluster_version = "1.30"

  cluster_endpoint_public_access  = true


  vpc_id                   = module.vpc.vpc_id
  
  control_plane_subnet_ids = module.vpc.private_subnets

  subnet_ids               = module.vpc.private_subnets
  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = ["t2.micro"]
    update_launch_template_default_version = true
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }    
  }

  eks_managed_node_groups = {
    "${terraform.workspace}-node" = {
      min_size     = 1
      max_size     = 10
      desired_size = 4

      instance_types = ["t2.micro"]
      subnet_ids     = module.vpc.public_subnets
      enable_public_ip = true
    }
  }

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = terraform.workspace
  }


}

resource "aws_eks_addon" "cni" {
  cluster_name = module.eks.cluster_name
  addon_name   = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE" 
} 

# resource "aws_eks_addon" "coredns" {
#   cluster_name = module.eks.cluster_name
#   addon_name   = "coredns"
#   addon_version               = "v1.11.1-eksbuild.9"
#   #resolve_conflicts_on_create = "OVERWRITE"
#   resolve_conflicts_on_update = "PRESERVE" 
# }

resource "aws_eks_addon" "proxy" {
  cluster_name = module.eks.cluster_name
  addon_name   = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE" 
}



data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "oidc_provider" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}



module "alb_controller" {
  source                           = "./modules/alb-controller"
  cluster_name                     = var.cluster_name
  cluster_identity_oidc_issuer     = data.aws_eks_cluster.cluster.identity.0.oidc.0.issuer
  cluster_identity_oidc_issuer_arn = data.aws_iam_openid_connect_provider.oidc_provider.arn
  aws_region                       = var.region
}

module "cluster-auto-scaler" {
  source                           = "./modules/cluster-autoscaller"
  cluster_name                     = var.cluster_name
  cluster_identity_oidc_issuer     = data.aws_eks_cluster.cluster.identity.0.oidc.0.issuer
  cluster_identity_oidc_issuer_arn = data.aws_iam_openid_connect_provider.oidc_provider.arn
  aws_region                       = var.region
}
