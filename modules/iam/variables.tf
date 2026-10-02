variable "name_prefix" {
  description = "Prefix for role and policy names (e.g. 'infra-forge-dev')."
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the EKS cluster the CI role is scoped to."
  type        = string
}

variable "region" {
  description = "AWS region, used to scope the ECR and log ARNs."
  type        = string
}

variable "account_id" {
  description = "AWS account ID, used to scope the ECR and log ARNs."
  type        = string
}

variable "admin_principal_arns" {
  description = "IAM user/role ARNs allowed to assume the cluster-admin role (e.g. SSO permission-set roles). MFA required."
  type        = list(string)

  validation {
    condition     = length(var.admin_principal_arns) > 0
    error_message = "Provide at least one admin principal, otherwise nobody can administer the cluster."
  }
}

variable "ci_principal_arns" {
  description = "IAM ARNs allowed to assume the CI deployer role (e.g. the OIDC-mapped CI role or a deploy user)."
  type        = list(string)
  default     = []
}

variable "ci_external_id" {
  description = "External ID condition on the CI role trust policy (confused-deputy protection)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "tags" {
  description = "Extra tags merged into every resource."
  type        = map(string)
  default     = {}
}
