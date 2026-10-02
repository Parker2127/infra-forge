terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Remote state for real use — uncomment and fill in before first apply:
  # backend "s3" {
  #   bucket         = "infra-forge-tfstate"
  #   key            = "dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "infra-forge-locks"
  #   encrypt        = true
  # }
}
