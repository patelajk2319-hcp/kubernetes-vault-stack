# Note: VSO itself is deployed via Helm in the tf-core module,
# This module configures VSO!!

# ============================================================================
# Kubernetes Authentication Backend
# ============================================================================

# How it works:
# 1. Pod gets a service account JWT token from Kubernetes
# 2. Pod sends JWT to Vault's /auth/kubernetes/login endpoint
# 3. Vault validates JWT with Kubernetes API server
# 4. Vault returns a Vault token with policies attached
# 5. Pod uses Vault token to access secrets
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

# Vault uses this configuration to validate service account JWT tokens
resource "vault_kubernetes_auth_backend_config" "config" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = "https://kubernetes.default.svc.cluster.local"
  # Required for certain Kubernetes versions where issuer validation fails
  disable_iss_validation = true
}

# ============================================================================
# Kubernetes Resources for VSO
# ============================================================================

# VaultConnection Resource
# Defines how VSO connects to the Vault server

# This is a shared resource - both static secrets (tf-static-elk) and
# dynamic secrets (tf-dynamic-elk) reference this same connection
resource "kubernetes_manifest" "vault_connection" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultConnection"
    metadata = {
      name      = "vault-connection"
      namespace = var.namespace
    }
    spec = {
      # Vault server address (cluster-internal service)
      address = "http://${var.vault_service_name}:8200"

      # Skip TLS verification (demo environment with self-signed certs)
      # For production, set to false and configure proper TLS
      skipTLSVerify = true
    }
  }

  depends_on = [vault_kubernetes_auth_backend_config.config]
}
