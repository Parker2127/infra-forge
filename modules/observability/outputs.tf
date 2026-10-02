output "grafana_service" {
  description = "Grafana Service name (port-forward to reach the UI)."
  value       = "kube-prometheus-stack-grafana"
}

output "prometheus_service" {
  description = "Prometheus Service name."
  value       = "kube-prometheus-stack-prometheus"
}
