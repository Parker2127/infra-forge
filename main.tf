# infra-forge root — one command builds the whole platform:
#   terraform init && terraform apply
#
# VPC -> EKS -> IAM -> observability, wired through module outputs.
# Validated without AWS credentials (init -backend=false + validate);
# applying needs real AWS credentials and uncommented S3 backend above.

provider "aws" {
  region = var.region

  default_tags {
    tags = merge(var.tags, {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    })
  }
}

locals {
  name_prefix  = "${var.project}-${var.environment}"
  cluster_name = "${local.name_prefix}-eks"
}

module "vpc" {
  source       = "./modules/vpc"
  name_prefix  = local.name_prefix
  cluster_name = local.cluster_name
  cidr_block   = var.vpc_cidr
  azs          = var.azs
  tags         = var.tags
}

module "eks" {
  source              = "./modules/eks"
  cluster_name        = local.cluster_name
  kubernetes_version  = var.kubernetes_version
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  tags                = var.tags
}

module "iam" {
  source               = "./modules/iam"
  name_prefix          = local.name_prefix
  cluster_arn          = "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:${local.cluster_name}"
  region               = var.region
  account_id           = data.aws_caller_identity.current.account_id
  admin_principal_arns = var.admin_principal_arns
  tags                 = var.tags
}

data "aws_caller_identity" "current" {}
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

module "observability" {
  source                 = "./modules/observability"
  namespace              = "monitoring"
  grafana_admin_password = var.grafana_admin_password

  depends_on = [module.eks]
}

# --- GCP / GKE path (opt-in via var.enable_gcp; validated, never applied
#     without real credentials — see modules/gcp/README.md) ------------------
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

module "gcp" {
  count = var.enable_gcp ? 1 : 0

  source             = "./modules/gcp"
  project_id         = var.gcp_project_id
  region             = var.gcp_region
  name_prefix        = local.name_prefix
  cluster_name       = "${local.name_prefix}-gke"
  node_count         = var.gcp_node_count
  node_min_count     = var.gcp_node_min_count
  node_max_count     = var.gcp_node_max_count
  wi_namespace       = "apps"
  wi_service_account = "app-sa"
}
