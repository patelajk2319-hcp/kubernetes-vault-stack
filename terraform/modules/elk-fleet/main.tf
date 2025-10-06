# ELK Fleet Server and Elastic Agent Module
# This module deploys Fleet Server and Elastic Agent for Vault log collection

# Vault Audit Logs PVC
resource "kubectl_manifest" "vault_audit_logs_pvc" {
  yaml_body = templatefile("${path.module}/manifests/vault-audit-logs-pvc.yaml", {
    namespace    = var.namespace
    storage_size = var.audit_logs_storage_size
  })
}

# ConfigMap for Fleet init script
resource "kubernetes_config_map" "fleet_init_script" {
  metadata {
    name      = "fleet-init-script"
    namespace = var.namespace
  }

  data = {
    "init-fleet.sh" = file("${path.module}/scripts/init-fleet.sh")
  }
}

# Fleet init ServiceAccount
resource "kubernetes_service_account" "fleet_init" {
  metadata {
    name      = "fleet-init"
    namespace = var.namespace
  }
}

# Fleet init Role
resource "kubernetes_role" "fleet_init" {
  metadata {
    name      = "fleet-init"
    namespace = var.namespace
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create", "get", "update", "patch"]
  }
}

# Fleet init RoleBinding
resource "kubernetes_role_binding" "fleet_init" {
  metadata {
    name      = "fleet-init"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.fleet_init.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.fleet_init.metadata[0].name
    namespace = var.namespace
  }
}

# Fleet init Job - sets up Fleet policies and tokens
resource "kubectl_manifest" "fleet_init_job" {
  yaml_body = templatefile("${path.module}/manifests/fleet-init-job.yaml", {
    namespace          = var.namespace
    kibana_host        = var.kibana_host
    elasticsearch_host = var.elasticsearch_host
  })

  depends_on = [
    kubernetes_config_map.fleet_init_script,
    kubernetes_role_binding.fleet_init
  ]
}

# Wait for Fleet init to complete
resource "time_sleep" "wait_for_fleet_init" {
  create_duration = "30s"

  depends_on = [kubectl_manifest.fleet_init_job]
}

# Fleet Server Deployment
resource "kubectl_manifest" "fleet_server_deployment" {
  yaml_body = templatefile("${path.module}/manifests/fleet-server-deployment.yaml", {
    namespace          = var.namespace
    fleet_version      = var.fleet_server_version
    elasticsearch_host = var.elasticsearch_host
    kibana_host        = var.kibana_host
  })

  depends_on = [time_sleep.wait_for_fleet_init]
}

# Fleet Server Service
resource "kubernetes_service" "fleet_server" {
  metadata {
    name      = "fleet-server"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "fleet-server"
    }

    port {
      name        = "http"
      port        = 8220
      target_port = 8220
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }

  depends_on = [kubectl_manifest.fleet_server_deployment]
}

# Wait for Fleet Server to be ready
resource "time_sleep" "wait_for_fleet_server" {
  create_duration = "60s"

  depends_on = [kubernetes_service.fleet_server]
}

# Elastic Agent Deployment
resource "kubectl_manifest" "elastic_agent_deployment" {
  yaml_body = templatefile("${path.module}/manifests/elastic-agent-deployment.yaml", {
    namespace     = var.namespace
    fleet_version = var.fleet_server_version
  })

  depends_on = [time_sleep.wait_for_fleet_server]
}
