variable "project" {
  description = "Project slug used in resource names."
  type        = string
  default     = "infra-forge"
}

variable "environment" {
  description = "Environment name (dev/stage/prod). One directory per environment in real use."
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Two availability zones."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "kubernetes_version" {
  description = "EKS control-plane version."
  type        = string
  default     = "1.31"
}

variable "node_instance_types" {
  description = "Node group instance types."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type        = number
  default     = 2
  description = "Desired node count."
}

variable "admin_principal_arns" {
  description = "SSO/admin principal ARNs for the cluster-admin role."
  type        = list(string)
  default     = []
}

variable "grafana_admin_password" {
  description = "Grafana admin password (TF_VAR_grafana_admin_password in real use)."
  type        = string
  sensitive   = true
  default     = "change-me-in-prod"
}

variable "tags" {
  description = "Extra tags for all resources."
  type        = map(string)
  default     = {}
}

# --- GCP / GKE path (opt-in; AWS path is untouched when false) --------------
variable "enable_gcp" {
  description = "Build the GCP/GKE foundation (modules/gcp) alongside the AWS stack."
  type        = bool
  default     = false
}

variable "gcp_project_id" {
  description = "GCP project ID. Required when enable_gcp = true."
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_gcp || can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.gcp_project_id))
    error_message = "gcp_project_id must be a valid GCP project ID when enable_gcp = true."
  }
}

variable "gcp_region" {
  description = "GCP region for the GKE foundation."
  type        = string
  default     = "asia-south1"
}

variable "gcp_node_count" {
  description = "Initial GKE node pool size."
  type        = number
  default     = 2
}

variable "gcp_node_min_count" {
  description = "GKE autoscaler floor."
  type        = number
  default     = 1
}

variable "gcp_node_max_count" {
  description = "GKE autoscaler ceiling."
  type        = number
  default     = 5
}
