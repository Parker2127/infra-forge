variable "project_id" {
  description = "GCP project ID (e.g. 'my-project-123456'). All resources and IAM bindings are scoped to this project."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID: lowercase, 6-30 chars, starts with a letter."
  }
}

variable "region" {
  description = "GCP region for the VPC, subnet, and regional GKE cluster."
  type        = string
  default     = "asia-south1" # Mumbai — closest to the target job market

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.region))
    error_message = "region must look like a GCP region, e.g. asia-south1."
  }
}

variable "name_prefix" {
  description = "Prefix applied to resource names (e.g. 'infra-forge-dev')."
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name. Lowercase letters, digits, and hyphens only."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{1,40}$", var.cluster_name))
    error_message = "cluster_name must be 1-40 chars of lowercase letters, digits, or hyphens."
  }
}

variable "subnet_cidr" {
  description = "Primary CIDR for the GKE subnet."
  type        = string
  default     = "10.10.0.0/20"

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid CIDR block, e.g. 10.10.0.0/20."
  }
}

variable "pods_cidr" {
  description = "Secondary range CIDR for pod IPs (VPC-native / alias IPs)."
  type        = string
  default     = "10.11.0.0/16"

  validation {
    condition     = can(cidrhost(var.pods_cidr, 0))
    error_message = "pods_cidr must be a valid CIDR block, e.g. 10.11.0.0/16."
  }
}

variable "services_cidr" {
  description = "Secondary range CIDR for ClusterIP service IPs."
  type        = string
  default     = "10.12.0.0/16"

  validation {
    condition     = can(cidrhost(var.services_cidr, 0))
    error_message = "services_cidr must be a valid CIDR block, e.g. 10.12.0.0/16."
  }
}

variable "master_cidr" {
  description = "/28 CIDR for the private control-plane endpoints. Must not overlap any peered network."
  type        = string
  default     = "172.16.0.0/28"

  validation {
    condition     = can(cidrhost(var.master_cidr, 0)) && tonumber(split("/", var.master_cidr)[1]) == 28
    error_message = "master_cidr must be a /28 CIDR block, e.g. 172.16.0.0/28."
  }
}

variable "release_channel" {
  description = "GKE release channel: RAPID, REGULAR, or STABLE."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be one of RAPID, REGULAR, STABLE."
  }
}

variable "maintenance_start" {
  description = "Recurring maintenance window start (RFC3339, UTC)."
  type        = string
  default     = "2026-01-01T20:30:00Z" # 02:00 IST — quiet hours
}

variable "maintenance_end" {
  description = "Recurring maintenance window end (RFC3339, UTC)."
  type        = string
  default     = "2026-01-02T00:30:00Z" # 06:00 IST
}

variable "maintenance_recurrence" {
  description = "Recurring maintenance window schedule (RFC2445 recurrence)."
  type        = string
  default     = "FREQ=WEEKLY;BYDAY=SU"
}

variable "machine_type" {
  description = "GCE machine type for the node pool."
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Boot disk size (GB) per node."
  type        = number
  default     = 50

  validation {
    condition     = var.disk_size_gb >= 10 && var.disk_size_gb <= 1000
    error_message = "disk_size_gb must be between 10 and 1000."
  }
}

variable "node_count" {
  description = "Initial node count for the node pool (autoscaler takes over after creation)."
  type        = number
  default     = 2

  validation {
    condition     = var.node_count >= var.node_min_count && var.node_count <= var.node_max_count
    error_message = "node_count must sit between node_min_count and node_max_count."
  }
}

variable "node_min_count" {
  description = "Autoscaler floor for the node pool."
  type        = number
  default     = 1

  validation {
    condition     = var.node_min_count >= 1
    error_message = "node_min_count must be at least 1 (a private cluster needs nodes to run system pods)."
  }
}

variable "node_max_count" {
  description = "Autoscaler ceiling for the node pool."
  type        = number
  default     = 5

  validation {
    condition     = var.node_max_count <= 20
    error_message = "node_max_count is capped at 20 in this module — raise it deliberately if you need more."
  }
}

variable "wi_namespace" {
  description = "Kubernetes namespace of the example Workload Identity service account."
  type        = string
  default     = "apps"
}

variable "wi_service_account" {
  description = "Kubernetes service account name bound to the example Google service account via Workload Identity."
  type        = string
  default     = "app-sa"
}

variable "deletion_protection" {
  description = "GKE deletion protection. Keep true in prod; false lets terraform destroy tear the cluster down."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Extra GCP labels merged into node configs."
  type        = map(string)
  default     = {}
}
