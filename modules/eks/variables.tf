variable "cluster_name" {
  description = "Name of the EKS cluster (also prefixes IAM roles and the node group)."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the control plane, e.g. 1.31."
  type        = string
  default     = "1.31"

  validation {
    condition     = can(regex("^1\\.(2[89]|[3][0-9])$", var.kubernetes_version))
    error_message = "kubernetes_version must look like 1.28 - 1.39, e.g. \"1.31\"."
  }
}

variable "private_subnet_ids" {
  description = "Private subnets for the control plane ENIs and worker nodes."
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Expose the public API endpoint. Disable for private-only clusters."
  type        = bool
  default     = true
}

variable "enabled_cluster_log_types" {
  description = "Control-plane log types shipped to CloudWatch."
  type        = list(string)
  default     = ["api", "audit"]
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired node count."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum node count."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum node count."
  type        = number
  default     = 4
}

variable "enable_irsa" {
  description = "Create the OIDC provider and an example IRSA role."
  type        = bool
  default     = true
}

variable "oidc_thumbprint" {
  description = "Thumbprint of the OIDC root CA (Amazon Root CA 1)."
  type        = string
  default     = "9e99a48a9960b14926bb7f3b02e22da2b0ab728"
}

variable "irsa_namespace" {
  description = "Kubernetes namespace of the example IRSA service account."
  type        = string
  default     = "monitoring"
}

variable "irsa_service_account" {
  description = "Service account name for the example IRSA role."
  type        = string
  default     = "prometheus"
}

variable "irsa_policy_arn" {
  description = "Managed policy attached to the example IRSA role."
  type        = string
  default     = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

variable "tags" {
  description = "Extra tags merged into every resource."
  type        = map(string)
  default     = {}
}
