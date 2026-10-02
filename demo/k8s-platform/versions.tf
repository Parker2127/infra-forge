terraform {
  required_version = ">= 1.9.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32"
    }
  }

  # Local state is fine for the demo. The AWS root config shows the
  # S3+DynamoDB remote-state pattern for real environments.
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}
