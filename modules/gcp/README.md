# GCP module

Private, VPC-native GKE foundation with Workload Identity — the GCP
counterpart to `modules/eks`. A regional cluster (control plane replicated
across zones), private nodes, autoscaled node pool on a least-privilege
service account, Calico network policy, and GKE-managed logging/monitoring.

## What it builds

- `google_compute_network` + `google_compute_subnetwork` — custom VPC, no
  auto-created subnets; the GKE subnet carries secondary ranges `pods` and
  `services` (alias IPs, VPC-native routing — no overlay).
- `google_container_cluster` — regional, private (`enable_private_nodes`),
  release channel + weekly maintenance window, Workload Identity enabled.
- `google_container_node_pool` — autoscaling (min/max), auto-repair and
  auto-upgrade, shielded nodes, `max_unavailable = 0` rolling upgrades.
- `google_service_account.nodes` — logWriter + metricWriter + monitoring
  viewer only. No Editor, no Owner, no broad `cloud-platform` IAM roles.
- `google_service_account.workload` + `roles/iam.workloadIdentityUser`
  binding — the pod-level credential pattern (see below).

## Workload Identity vs the old ways

Pods never hold GCP keys. A Kubernetes ServiceAccount in
`var.wi_namespace`/`var.wi_service_account` is annotated to impersonate
`google_service_account.workload`; GKE's OIDC federation mints short-lived
tokens at runtime. Same idea as IRSA on EKS, GCP-native.

## Validation status

**Validated, not applied** — exactly like the AWS modules in this repo.
`terraform init -backend=false` + `terraform validate` need no GCP
credentials; a real `apply` needs `GOOGLE_APPLICATION_CREDENTIALS` (or
`gcloud auth application-default login`) plus a real `project_id`.

## Inputs

| Name | Description | Default |
|---|---|---|
| `project_id` | GCP project ID, validated | — |
| `region` | GCP region | `asia-south1` |
| `name_prefix` | Prefix for resource names | — |
| `cluster_name` | GKE cluster name, validated | — |
| `subnet_cidr` / `pods_cidr` / `services_cidr` | Subnet + secondary ranges | `10.10.0.0/20`, `10.11.0.0/16`, `10.12.0.0/16` |
| `master_cidr` | Private control-plane /28 | `172.16.0.0/28` |
| `release_channel` | RAPID / REGULAR / STABLE | `REGULAR` |
| `maintenance_start` / `maintenance_end` / `maintenance_recurrence` | Upgrade window | Sun 02:00–06:00 IST |
| `machine_type` / `disk_size_gb` | Node shape | `e2-medium`, `50` |
| `node_count` / `node_min_count` / `node_max_count` | Pool sizing, validated | `2` / `1` / `5` |
| `wi_namespace` / `wi_service_account` | Example WI binding | `apps` / `app-sa` |
| `deletion_protection` | GKE deletion protection | `false` |
| `labels` | Extra GCP labels | `{}` |

## Outputs

`cluster_name`, `cluster_endpoint`, `cluster_ca_certificate`,
`cluster_location`, `network_self_link`, `subnetwork_self_link`,
`node_service_account_email`, `workload_service_account_email`.
