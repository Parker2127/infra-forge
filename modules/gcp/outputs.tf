output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.this.name
}

output "cluster_endpoint" {
  description = "GKE API endpoint."
  value       = google_container_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate."
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
}

output "cluster_location" {
  description = "Region the regional cluster lives in."
  value       = google_container_cluster.this.location
}

output "network_self_link" {
  description = "Self-link of the VPC."
  value       = google_compute_network.this.self_link
}

output "subnetwork_self_link" {
  description = "Self-link of the GKE subnet."
  value       = google_compute_subnetwork.this.self_link
}

output "node_service_account_email" {
  description = "Email of the least-privilege node service account."
  value       = google_service_account.nodes.email
}

output "workload_service_account_email" {
  description = "Email of the Google service account bound via Workload Identity."
  value       = google_service_account.workload.email
}
