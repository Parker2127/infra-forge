variable "name_prefix" {
  description = "Prefix applied to the Name tag of every resource (e.g. 'infra-forge-dev')."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name, used for the kubernetes.io/cluster subnet tags AWS load balancer controller relies on."
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC. Must leave room for 2*len(azs) /24 subnets."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid CIDR block, e.g. 10.0.0.0/16."
  }
}

variable "azs" {
  description = "Availability zones to spread subnets across. Exactly two keeps the demo topology simple."
  type        = list(string)

  validation {
    condition     = length(var.azs) == 2
    error_message = "This module builds a two-AZ topology; provide exactly 2 availability zones."
  }
}

variable "enable_nat_gateway_per_az" {
  description = "Create one NAT gateway per AZ (HA, higher cost) instead of a single shared one."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags merged into every resource."
  type        = map(string)
  default     = {}
}
