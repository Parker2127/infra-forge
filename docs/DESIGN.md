# infra-forge — design notes

Why things are built the way they are: the tradeoffs, the non-goals, and what
production would change.

## What happens on `terraform apply` at the root

Four modules execute in dependency order: VPC creates the network (2 AZs,
public/private subnets, NAT, route tables); EKS builds the cluster and managed
node group in the private subnets and outputs the endpoint; the kubernetes and
helm providers are configured from those outputs; IAM creates the
cluster-admin and ci-deployer roles; observability installs
kube-prometheus-stack via Helm. Outputs give you the cluster endpoint and the
role ARNs to finish the aws-iam-authenticator mapping.

## Secrets handling

The Grafana admin password is a `sensitive` variable — never in a committed
`.tfvars`. In real use it's injected via `TF_VAR_grafana_admin_password` from
AWS Secrets Manager or Vault. The IRSA pattern in the EKS module exists for
the same reason: pods get short-lived credentials via ServiceAccount
annotations instead of static keys baked anywhere.

## Partial apply failures

Terraform records each created resource in state as it goes, so a rerun only
retries what didn't finish — applies are idempotent. For truly partial
failures (e.g. the API accepted a resource but the connection dropped), the
next `plan` reconciles state against reality. That's also why the drift
detector exists: anything changed outside Terraform shows up on the next plan.

## Adding a second environment

Copy the root into `envs/staging/` with its own `terraform.tfvars` and a
separate S3 backend key — the modules are already environment-agnostic via
`name_prefix`. Same code, different state, no duplication. The demo config's
`environment` variable shows the labeling pattern.

## Single NAT gateway: cost vs. blast radius

One NAT is ~$32/month cheaper per AZ and fine for dev.
`enable_nat_gateway_per_az = true` gives each AZ its own egress path for
production. The tradeoff is a variable, not an accident.

## How drift detection works

`terraform plan -detailed-exitcode`: exit 0 = state matches reality, 2 = the
plan would change something, anything else = error. The script turns that
contract into NO DRIFT / DRIFT DETECTED / ERROR with CI-friendly exit codes
and prints the diff on drift. In CI it runs the full loop: apply on a
throwaway k3s API → expect clean → inject an out-of-band `kubectl label` →
expect detected → revert.

## Why ResourceQuotas and LimitRanges

Without quotas, one namespace can starve the cluster (a runaway job eats all
CPU). Without LimitRanges, pods with no requests/limits get scheduled with
best-effort QoS and are the first killed under pressure. The demo sets
per-namespace quotas (apps gets the biggest share) and sane container
defaults (100m/128Mi request, 500m/512Mi limit).

## RBAC design

Two personas: `platform-admins` (group → ClusterRole, full access — the
humans who run the platform) and `ci-deployer` (user → namespaced Role in
`apps` only, can manage workloads but can't touch RBAC, nodes, or other
namespaces). The AWS-side mirror is the `ci-deployer` IAM role scoped to
`eks:DescribeCluster` + ECR push/pull under the project prefix, with an
external ID on the trust policy against confused-deputy attacks.

## What production would add

Uncomment the S3+DynamoDB backend (state locking, encryption), per-AZ NAT
gateways, private EKS endpoint with VPN/Direct Connect access, Alertmanager
routes to PagerDuty/Opsgenie, and IRSA roles per workload instead of one
example. Also: the demo's local state file would never fly — that's
documented as demo-only.

## Deliberate non-goals

The AWS modules were validated, not applied — no credentials in this
environment, and I'm not going to claim an apply I didn't run. The demo ran
against k3s in API-only mode (no kubelet), which is all the kubernetes
provider needs; pod scheduling wasn't part of what I measured. Every number
in the README's results table comes from an actual run.

## Workload Identity vs IRSA

Same goal, same primitive: give pods a cloud identity with no static keys,
using OIDC federation under the hood. On EKS (IRSA) you register the
cluster's OIDC issuer as an IAM OIDC provider, write a trust policy on an
IAM role that allows `sts:AssumeRoleWithWebIdentity` only when the token's
`sub` claim matches `system:serviceaccount:<ns>:<sa>`, and annotate the K8s
ServiceAccount with the role ARN; the SDK exchanges the projected token at
STS for temp AWS credentials. On GKE (Workload Identity) the direction is
mirrored: the workload pool is project-scoped (`<project>.svc.id.goog`),
you create a Google service account and grant the K8s identity
`roles/iam.workloadIdentityUser` on it, and annotate the K8s ServiceAccount
with the *Google* SA's email — `iam.gke.io/gcp-service-account`. Google
client libraries then mint short-lived access tokens via the IAM Credentials
API. Practical differences: IRSA trust is per-cluster (each cluster
registers its own OIDC provider); Workload Identity's pool is per-project,
so any WI-enabled cluster in the project can use it. In this repo,
`modules/eks` shows the IRSA side and `modules/gcp` the WI side — same
pattern, both clouds, no keys in either.

## Secondary ranges on GKE vs EKS pod networking

On EKS the aws-vpc-cni assigns real VPC IPs to pods, so every pod consumes
an address from the node subnets — that's exactly why `modules/vpc` carves
roomy /24s per AZ. GKE's VPC-native mode (alias IPs) instead allocates pod
IPs from a *secondary* range on the subnet and service IPs from another, so
the primary subnet stays small and pod scaling can't exhaust the VPC's main
address space. Trade-off to be aware of: secondary ranges are fixed at
subnet creation and can't be shrunk, and on EKS-style setups you watch
subnet exhaustion while on GKE you watch secondary-range exhaustion — same
capacity-planning instinct, different range to monitor.
