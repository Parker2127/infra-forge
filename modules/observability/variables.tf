variable "namespace" {
  description = "Namespace for the monitoring stack."
  type        = string
  default     = "monitoring"
}

variable "chart_version" {
  description = "Pinned kube-prometheus-stack chart version (reproducible installs)."
  type        = string
  default     = "61.3.2"
}

variable "prometheus_retention" {
  description = "How long Prometheus keeps samples."
  type        = string
  default     = "7d"
}

variable "grafana_admin_password" {
  description = "Grafana admin password. Pass via TF_VAR_ or a secrets manager, never commit it."
  type        = string
  sensitive   = true
}

variable "enable_alertmanager" {
  description = "Deploy Alertmanager alongside Prometheus."
  type        = bool
  default     = true
}
