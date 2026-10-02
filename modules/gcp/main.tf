# GCP module — private, VPC-native GKE cluster with Workload Identity.
#
# One VPC, one regional subnet with secondary ranges for pods/services,
# a regional (multi-zone) private GKE cluster, an autoscaled node pool on
# a least-privilege service account, and a Workload Identity binding that
# lets a Kubernetes ServiceAccount impersonate a Google service account —
# the GCP equivalent of the IRSA pattern in modules/eks.
#
# Cost note: a regional private cluster's control plane is free; you pay
# only for nodes. e2-medium x2 default keeps lab spend small.

resource "google_compute_network" "this" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "VPC for ${var.cluster_name} (managed by infra-forge)"
}

resource "google_compute_subnetwork" "this" {
  name                     = "${var.name_prefix}-subnet"
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = google_compute_network.this.id
  private_ip_google_access = true
  description              = "Primary + secondary (pods/services) ranges for ${var.cluster_name}"

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

# --- Node service account: least privilege -------------------------------
# Nodes get log/metric writing only — no broad cloud-platform roles, and
# definitely not Owner/Editor.
resource "google_service_account" "nodes" {
  account_id   = "${var.name_prefix}-gke-nodes"
  display_name = "GKE node service account for ${var.cluster_name}"
}

resource "google_project_iam_member" "nodes_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_project_iam_member" "nodes_metrics" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_project_iam_member" "nodes_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

# --- Workload Identity: the GCP answer to IRSA -----------------------------
# Workload pods in ${var.wi_namespace}/${var.wi_service_account} can
# impersonate google_service_account.workload — no static keys anywhere.
resource "google_service_account" "workload" {
  account_id   = "${var.name_prefix}-wi-app"
  display_name = "Workload Identity example for ${var.cluster_name}"
}

resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = google_service_account.workload.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.wi_namespace}/${var.wi_service_account}]"
}

# --- Private GKE cluster ----------------------------------------------------
resource "google_container_cluster" "this" {
  name     = var.cluster_name
  location = var.region # regional = control plane replicated across zones

  network    = google_compute_network.this.id
  subnetwork = google_compute_subnetwork.this.id

  # We manage our own node pool below; drop the default one.
  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel {
    channel = var.release_channel
  }

  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_start
      end_time   = var.maintenance_end
      recurrence = var.maintenance_recurrence
    }
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # API reachable publicly; nodes are private
    master_ipv4_cidr_block  = var.master_cidr
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  deletion_protection = var.deletion_protection
}

# --- Autoscaled node pool ----------------------------------------------------
resource "google_container_node_pool" "this" {
  name               = "${var.cluster_name}-pool"
  cluster            = google_container_cluster.this.id
  location           = var.region
  initial_node_count = var.node_count

  autoscaling {
    min_node_count = var.node_min_count
    max_node_count = var.node_max_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = var.machine_type
    disk_size_gb    = var.disk_size_gb
    disk_type       = "pd-balanced"
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = merge(var.labels, { cluster = var.cluster_name })
  }
}
