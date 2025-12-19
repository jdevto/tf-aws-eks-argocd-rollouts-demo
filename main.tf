module "vpc" {
  source = "./modules/vpc"

  name               = var.cluster_name
  cluster_name       = var.cluster_name
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b"]

  tags = merge(local.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  subnet_ids = module.vpc.private_subnet_ids

  tags = local.tags
}

# AWS Load Balancer Controller
module "aws_lb_controller" {
  source = "./modules/aws-lb-controller"

  cluster_name               = module.eks.cluster_name
  aws_lb_controller_role_arn = module.eks.aws_lb_controller_role_arn
  vpc_id                     = module.vpc.vpc_id

  depends_on = [module.eks]
}

module "argocd" {
  source = "./modules/argocd"

  repo_url        = var.repo_url
  target_revision = var.target_revision
  aws_region      = var.aws_region
  cluster_name    = var.cluster_name
  subnet_ids      = module.vpc.public_subnet_ids

  depends_on = [module.eks, module.aws_lb_controller]
}
