# Observability module

Prometheus + Grafana via the `kube-prometheus-stack` Helm chart (pinned
version), plus a starter "Cluster at a glance" dashboard shipped as a
ConfigMap. Grafana's dashboard sidecar auto-discovers any ConfigMap labelled
`grafana_dashboard=1`, so adding dashboards later is just `kubectl apply`.

## Secrets

`grafana_admin_password` is `sensitive`. In real use, feed it via
`TF_VAR_grafana_admin_password` from a secrets manager (AWS Secrets Manager,
Vault) — never in a `.tfvars` file that gets committed.
