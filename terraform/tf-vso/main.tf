# VSO Configuration
# Note: VSO is deployed via Helm in tf-core, this module configures it

# Kubernetes auth backend
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

# Kubernetes auth config
resource "vault_kubernetes_auth_backend_config" "config" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = "https://kubernetes.default.svc.cluster.local"
  disable_iss_validation = true
}

# VaultConnection resource (shared by static and dynamic secrets)
resource "kubernetes_manifest" "vault_connection" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultConnection"
    metadata = {
      name      = "vault-connection"
      namespace = var.namespace
    }
    spec = {
      address       = "http://${var.vault_service_name}:8200"
      skipTLSVerify = true
    }
  }

  depends_on = [vault_kubernetes_auth_backend_config.config]
}
