output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API endpoint."
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "cluster_admin_role_arn" {
  description = "Map this role to cluster-admin via aws-iam-authenticator."
  value       = module.iam.cluster_admin_role_arn
}

output "ci_deployer_role_arn" {
  description = "Use this role for CI AWS credentials."
  value       = module.iam.ci_deployer_role_arn
}

output "grafana_access" {
  description = "How to reach Grafana after apply."
  value       = "kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80"
}

# --- GCP outputs (null unless enable_gcp = true) ------------------------------
output "gke_cluster_name" {
  description = "GKE cluster name (null unless enable_gcp = true)."
  value       = one(module.gcp[*].cluster_name)
}

output "gke_cluster_endpoint" {
  description = "GKE API endpoint (null unless enable_gcp = true)."
  value       = one(module.gcp[*].cluster_endpoint)
}

output "gke_network_self_link" {
  description = "Self-link of the GCP VPC (null unless enable_gcp = true)."
  value       = one(module.gcp[*].network_self_link)
}
