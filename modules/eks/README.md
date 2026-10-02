# EKS module

Managed Kubernetes control plane plus a private managed node group, with
least-privilege IAM throughout:

- Dedicated cluster and node IAM roles (no `AdministratorAccess` anywhere).
- Node group lives in **private** subnets; control plane API can be
  public or private via `endpoint_public_access`.
- **IRSA** example: OIDC provider plus a role assumable only by one
  ServiceAccount (`system:serviceaccount:<ns>:<sa>`), so pods get scoped
  AWS credentials instead of static keys.

## Inputs

| Name | Description | Default |
|---|---|---|
| `cluster_name` | Cluster name (prefixes roles/node group) | — |
| `kubernetes_version` | Control-plane version, validated `1.28`-`1.39` | `1.31` |
| `vpc_id` / `private_subnet_ids` | Network placement | — |
| `endpoint_public_access` | Public API endpoint | `true` |
| `node_instance_types`, `node_desired/min/max_size` | Node group sizing | `t3.medium`, 2/1/4 |
| `enable_irsa`, `irsa_*` | OIDC + example workload role | enabled |
| `tags` | Extra tags | `{}` |
