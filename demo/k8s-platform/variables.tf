variable "kubeconfig_path" {
  description = "Kubeconfig pointing at the target cluster (k3s demo API here, EKS in real use)."
  type        = string
  default     = "/etc/rancher/k3s/k3s.yaml"
}

variable "environment" {
  description = "Label applied to every namespace, so drift and cost tooling can tell environments apart."
  type        = string
  default     = "demo"
}
