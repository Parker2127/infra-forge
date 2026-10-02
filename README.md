# infra-forge

A production-grade Terraform provisioning platform: one command builds a
complete Kubernetes platform baseline — network, cluster, IAM, observability —
with drift detection proving it stays that way.

Everything here is real code;
the AWS side is validated (`terraform validate`, no credentials needed) and
the Kubernetes platform baseline genuinely applies against a live cluster API
(see the demo below).

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  terraform apply   (root)                                   │
│                                                             │
│  modules/vpc ──► VPC, 2 AZs, public/private subnets,        │
│                   IGW, NAT, route tables                    │
│                       │                                     │
│  modules/eks ──► EKS cluster + managed node group           │
│                   (private subnets), IRSA OIDC role          │
│                       │                                     │
│  modules/iam ──► cluster-admin role (MFA) +                  │
│                   ci-deployer role (scoped ECR/EKS)          │
│                       │                                     │
│  modules/observability ──► kube-prometheus-stack             │
│                   (Helm) + Grafana dashboard ConfigMap       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  enable_gcp = true  (opt-in, off by default)                │
│                                                             │
│  modules/gcp ──► private VPC-native GKE cluster              │
│                   (VPC + secondary ranges, node pool,        │
│                    Workload Identity)                        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  demo/k8s-platform  →  terraform apply against any cluster   │
│                                                             │
│  namespaces: platform / apps / monitoring                   │
│  RBAC:       ClusterRole+Binding (platform-admins group),    │
│              Role+Binding (ci-deployer in apps)              │
│  guardrails: ResourceQuota + LimitRange per namespace       │
│  network:    2 NetworkPolicies (default-deny, allow-same-ns) │
│                                                             │
│  scripts/drift-detect.sh watches it via plan -detailed-     │
│  exitcode: 0 = clean, 2 = drift, 1 = error                  │
└─────────────────────────────────────────────────────────────┘
```

## Repo layout

```
infra-forge/
├── main.tf / variables.tf / outputs.tf / versions.tf   # AWS root (VPC→EKS→IAM→observability)
├── terraform.tfvars.example
├── modules/
│   ├── vpc/             # 2-AZ network, NAT, route tables
│   ├── eks/             # cluster, node group, IRSA
│   ├── iam/             # cluster-admin + ci-deployer roles (least privilege)
│   ├── gcp/             # private GKE cluster + Workload Identity (opt-in)
│   └── observability/   # kube-prometheus-stack + Grafana dashboard
├── demo/k8s-platform/   # live demo: namespaces, RBAC, quotas, policies
├── scripts/drift-detect.sh
├── docs/DESIGN.md        # design rationale and tradeoffs
└── .github/workflows/ci.yml
```

## Run the demo end-to-end

Prereqs: `terraform >= 1.9`, a Kubernetes cluster. The commands below use a
local k3s API server (API-only mode — no kubelet needed, we only talk to the API):

```bash
# 1. (If needed) start the k3s API server
sudo nohup /usr/local/bin/k3s server --disable-agent --disable traefik \
  --disable servicelb --flannel-backend=none --disable-network-policy \
  --disable-helm-controller --disable-cloud-controller >/tmp/k3s.log 2>&1 &
# wait ~25s, then:
sudo /usr/local/bin/k3s kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get ns

# 2. One-command platform build
cd demo/k8s-platform
terraform init
time terraform apply -auto-approve
# Apply complete! Resources: 15 added, 0 changed, 0 destroyed.

# 3. Drift detection — clean state
../../scripts/drift-detect.sh
# NO DRIFT: live cluster matches Terraform state.

# 4. Make an out-of-band change (like a teammate kubectl-editing at 2am)
kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml label namespace apps drift-demo=true

# 5. Watch the detector catch it
../../scripts/drift-detect.sh
# DRIFT DETECTED: live cluster differs from Terraform state.
# --- plan diff ---
#   # kubernetes_namespace.this["apps"] will be updated in-place
#   ~ resource "kubernetes_namespace" "this" {
# Plan: 0 to add, 1 to change, 0 to destroy.

# 6. Revert and confirm clean again
kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml label namespace apps drift-demo-
../../scripts/drift-detect.sh
# NO DRIFT: live cluster matches Terraform state.
```

Validate the AWS side without credentials:

```bash
terraform init -backend=false
terraform validate   # Success! The configuration is valid.
```

## GCP path (opt-in)

`modules/gcp` is the GCP counterpart to the AWS stack: a private,
VPC-native GKE cluster with a regional control plane, an autoscaled node
pool on a least-privilege service account, and a Workload Identity binding
(the GCP equivalent of IRSA — see `docs/DESIGN.md`).

It's gated behind `enable_gcp` (default `false`), so the AWS path is
completely untouched when it's off. To use it, set in `terraform.tfvars`
(see `terraform.tfvars.example`):

```hcl
enable_gcp     = true
gcp_project_id = "my-project-123456"
gcp_region     = "asia-south1"
```

Same contract as the AWS modules: validated, not applied — no GCP
credentials exist in this environment, so `terraform init -backend=false`
+ `terraform validate` is as far as it goes here. A real apply needs
`GOOGLE_APPLICATION_CREDENTIALS` and a real project ID.

## How drift detection works

`terraform plan -detailed-exitcode` is the whole trick: exit code `0` means
"nothing to do" (state == reality), `2` means "the plan would change
something" (reality drifted), anything else is an error. The script wraps
that contract into a CI-friendly verdict with no dependencies beyond bash
and terraform. In CI it runs against a throwaway k3s API server: apply →
expect clean → inject drift → expect detected → revert.

## Measured results

All numbers below were measured on 2026-10-02 against the live k3s API on
this machine — no estimates, no projections.

| Check | Result |
|---|---|
| `terraform validate` (root, 5 modules, `enable_gcp=false` default) | Success |
| `terraform validate` (root, `enable_gcp=true`) | Success |
| `terraform validate` (modules/gcp standalone) | Success |
| `terraform validate` (demo k8s-platform) | Success |
| `terraform fmt -check -recursive` | Clean |
| `tflint --recursive` | 0 issues |
| Demo `terraform apply` | **15 added**, 0 changed, 0 destroyed |
| Demo apply wall-clock | **1.9s** (`time terraform apply`) |
| Drift check, clean state | NO DRIFT, exit 0 |
| Drift check after out-of-band `kubectl label` | DRIFT DETECTED, exit 2, diff shown |
| Drift check after revert | NO DRIFT, exit 0 |

What was *not* done: the AWS modules were validated, not applied (no AWS
credentials in this environment). The demo ran against k3s API-only mode
(no kubelet), which is all the kubernetes provider needs. The GCP module
was likewise validated, not applied (no GCP credentials here). One
tooling note: `terraform validate` does not evaluate variable validation
rules against supplied values — those fire at plan/apply time, so the
`enable_gcp=true` + invalid project-ID rejection was verified by
construction (same pattern as the AWS modules' validations), not by a
failing validate run.
