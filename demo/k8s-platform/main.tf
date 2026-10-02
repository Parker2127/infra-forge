# demo/k8s-platform — one-command platform baseline on any Kubernetes cluster.
#
#   terraform init && terraform apply
#
# Provisions the namespace layout, RBAC, quotas, limits, and network policy
# baseline that the AWS root config's EKS cluster would receive in production.
# Run it here against the local k3s API to demo the whole lifecycle,
# including drift detection (see scripts/drift-detect.sh).

locals {
  namespaces = ["platform", "apps", "monitoring"]

  common_labels = {
    "managed-by"  = "terraform"
    "project"     = "infra-forge"
    "environment" = var.environment
  }

  # Per-namespace compute guardrails.
  quotas = {
    platform   = { pods = "10", cpu = "2", memory = "4Gi", services = "5" }
    apps       = { pods = "20", cpu = "4", memory = "8Gi", services = "10" }
    monitoring = { pods = "10", cpu = "2", memory = "8Gi", services = "5" }
  }
}

# --- Namespaces ---------------------------------------------------------------
resource "kubernetes_namespace" "this" {
  for_each = toset(local.namespaces)

  metadata {
    name   = each.key
    labels = local.common_labels
  }
}

# --- RBAC ----------------------------------------------------------------------
# ClusterRole for platform admins, bound to the platform-admins group.
resource "kubernetes_cluster_role" "platform_admin" {
  metadata {
    name   = "platform-admin"
    labels = local.common_labels
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_cluster_role_binding" "platform_admin" {
  metadata {
    name   = "platform-admin"
    labels = local.common_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.platform_admin.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "platform-admins"
    api_group = "rbac.authorization.k8s.io"
  }
}

# Namespaced deployer role for the CI system in apps/.
resource "kubernetes_role" "app_deployer" {
  metadata {
    name      = "app-deployer"
    namespace = kubernetes_namespace.this["apps"].metadata[0].name
    labels    = local.common_labels
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "statefulsets", "daemonsets", "replicasets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "services", "configmaps", "secrets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding" "app_deployer" {
  metadata {
    name      = "app-deployer"
    namespace = kubernetes_namespace.this["apps"].metadata[0].name
    labels    = local.common_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.app_deployer.metadata[0].name
  }

  subject {
    kind      = "User"
    name      = "ci-deployer"
    api_group = "rbac.authorization.k8s.io"
  }
}

# --- Guardrails: quotas + limits --------------------------------------------------
resource "kubernetes_resource_quota" "this" {
  for_each = local.quotas

  metadata {
    name      = "compute-quota"
    namespace = kubernetes_namespace.this[each.key].metadata[0].name
    labels    = local.common_labels
  }

  spec {
    hard = each.value
  }
}

resource "kubernetes_limit_range" "this" {
  for_each = toset(local.namespaces)

  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.this[each.key].metadata[0].name
    labels    = local.common_labels
  }

  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "500m"
        memory = "512Mi"
      }
      default_request = {
        cpu    = "100m"
        memory = "128Mi"
      }
    }
  }
}

# --- Network policies --------------------------------------------------------------
resource "kubernetes_network_policy" "apps_default_deny" {
  metadata {
    name      = "default-deny-ingress"
    namespace = kubernetes_namespace.this["apps"].metadata[0].name
    labels    = local.common_labels
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy" "monitoring_allow_same_namespace" {
  metadata {
    name      = "allow-same-namespace"
    namespace = kubernetes_namespace.this["monitoring"].metadata[0].name
    labels    = local.common_labels
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {}
      }
    }
  }
}
