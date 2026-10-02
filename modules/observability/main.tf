# Observability module — Prometheus + Grafana via Helm, plus a starter dashboard.
#
# Installs kube-prometheus-stack into the monitoring namespace and ships one
# ConfigMap with a minimal "Cluster at a glance" dashboard that Grafana's
# dashboard sidecar picks up automatically (label grafana_dashboard=1).

resource "helm_release" "prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  values = [yamlencode({
    prometheus = {
      prometheusSpec = {
        retention      = var.prometheus_retention
        scrapeInterval = "30s"
      }
    }
    grafana = {
      adminPassword = var.grafana_admin_password
      # Sidecar auto-loads dashboards from ConfigMaps labelled grafana_dashboard=1.
      sidecar = {
        dashboards = { enabled = true, label = "grafana_dashboard", labelValue = "1" }
      }
    }
    # Keep lab costs sane: single replicas, no persistent volumes by default.
    alertmanager = { enabled = var.enable_alertmanager }
  })]

  timeout = 600
}

resource "kubernetes_config_map" "cluster_dashboard" {
  metadata {
    name      = "cluster-at-a-glance"
    namespace = var.namespace
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "cluster-at-a-glance.json" = jsonencode({
      title = "Cluster at a glance"
      tags  = ["infra-forge"]
      panels = [
        {
          title   = "CPU usage %"
          type    = "timeseries"
          targets = [{ expr = "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)" }]
        },
        {
          title   = "Memory usage %"
          type    = "timeseries"
          targets = [{ expr = "100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))" }]
        },
        {
          title   = "Pods not ready"
          type    = "stat"
          targets = [{ expr = "sum(kube_pod_status_ready{condition=\"false\"})" }]
        },
      ]
    })
  }

  depends_on = [helm_release.prometheus_stack]
}
