# ============================================================================
# Static Elasticsearch Secrets Demo
# ============================================================================


# KV v2 Secrets Engine Mount
resource "vault_mount" "kvv2" {
  path = "kvv2"
  type = "kv"
  options = {
    version = "2" # Use KV version 2 for versioning and soft delete
  }
  description = "KV v2 secrets engine for static secrets demonstration"
}

# Webapp Configuration Secret
# Stores static credentials for the demo
resource "vault_kv_secret_v2" "webapp_config" {
  mount = vault_mount.kvv2.path
  name  = "webapp/config"

  data_json = jsonencode({
    username = var.webapp_username
    password = var.webapp_password
  })

  depends_on = [vault_mount.kvv2]
}

# Elasticsearch Configuration Secret
# Stores Elasticsearch connection details for applications

# This secret contains:
# - Connection details: host, port, protocol
# - Admin credentials: username, password
# - Configuration: index name, full URL

# VSO will sync this to a Kubernetes secret named "elasticsearch-secret"
resource "vault_kv_secret_v2" "elasticsearch_config" {
  mount = vault_mount.kvv2.path
  name  = "elasticsearch/config"

  data_json = jsonencode({
    es_host     = var.elasticsearch_host
    es_port     = var.elasticsearch_port
    es_protocol = var.elasticsearch_protocol
    es_username = var.elasticsearch_username
    es_password = var.elasticsearch_password
    es_index    = var.elasticsearch_index
    # Computed full URL for convenience
    es_url = "${var.elasticsearch_protocol}://${var.elasticsearch_host}:${var.elasticsearch_port}"
  })

  depends_on = [vault_mount.kvv2]
}

# ============================================================================
# Kubernetes Service Account
# ============================================================================

# Service Account for Static Secrets Demo
# This service account is used by the webapp to authenticate to Vault
resource "kubernetes_service_account" "static_webapp" {
  metadata {
    name      = "elk-static-webapp-svc-acc"
    namespace = var.namespace
  }
}

# Static Secrets Vault Policy
# Creates the policy in Vault from the policy document
resource "vault_policy" "static_secrets_policy" {
  name   = "static-secrets-policy"
  policy = data.vault_policy_document.static_secrets_policy.hcl
}

# ============================================================================
# Kubernetes Auth Role
# ============================================================================

# Static Secrets Kubernetes Auth Role
# Maps Kubernetes service accounts to Vault policies for static secrets
#
# This role:
# - Binds to specific service accounts (default, VSO controller)
# - Restricts to a specific namespace
# - Attaches the static-secrets-policy (grants read access to KV secrets)
# - Issues tokens with 1-hour TTL
# - Requires "vault" audience in JWT tokens
#
# When a pod with the "default" service account authenticates:
# 1. Vault validates the pod is in the correct namespace
# 2. Vault verifies the service account name matches
# 3. Vault issues a token with static-secrets-policy attached
# 4. Pod can now read secrets defined in static-secrets-policy
resource "vault_kubernetes_auth_backend_role" "static_secrets_role" {
  backend   = "kubernetes"
  role_name = "static-secrets-role"
  # Service accounts that can use this role
  bound_service_account_names = [
    kubernetes_service_account.static_webapp.metadata[0].name,
    "vault-secrets-operator-controller-manager"
  ]
  # Namespaces where these service accounts can authenticate
  bound_service_account_namespaces = [var.namespace]
  # Policies attached to the issued Vault token
  token_policies = [vault_policy.static_secrets_policy.name]
  # Token lifetime (1 hour)
  token_ttl = 3600
  # Required audience claim in JWT token
  # Format: <namespace>-<app>-<purpose>
  audience = "vault-stack-static-webapp-vault-auth"
}

# ============================================================================
# Kubernetes Resources for VSO Static Secrets
# ============================================================================

# VaultAuth Resource
# Defines how VSO authenticates to Vault for static secrets
#
# This creates a VaultAuth CRD that:
# - Uses Kubernetes auth method (service account tokens)
# - References the shared VaultConnection (created by tf-vso module)
# - Authenticates as the static-secrets-role
# - Allows VSO to fetch static secrets from Vault
#
# The default service account is used, which is available in all pods
# unless a different service account is specified
resource "kubectl_manifest" "vault_auth_static" {
  yaml_body = yamlencode({
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultAuth"
    metadata = {
      name      = "vault-auth-static"
      namespace = var.namespace
    }
    spec = {
      # Reference to the shared VaultConnection
      vaultConnectionRef = "vault-connection"

      # Use Kubernetes auth method
      method = "kubernetes"
      mount  = "kubernetes"

      kubernetes = {
        # Vault role that grants access to KV secrets
        role = "static-secrets-role"

        # Service account for authentication
        serviceAccount = kubernetes_service_account.static_webapp.metadata[0].name

        # Audience claim for JWT
        # Must match the audience configured in the Vault role
        audiences = ["vault-stack-static-webapp-vault-auth"]
      }
    }
  })

  depends_on = [vault_kubernetes_auth_backend_role.static_secrets_role]
}

# VaultStaticSecret Resource - Webapp Configuration
# Syncs the webapp secret from Vault to a Kubernetes secret

resource "kubectl_manifest" "webapp_secret" {
  yaml_body = yamlencode({
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultStaticSecret"
    metadata = {
      name      = "webapp-secret"
      namespace = var.namespace
    }
    spec = {
      # Reference to VaultAuth for authentication
      vaultAuthRef = "vault-auth-static"

      # KV v2 mount and path
      mount = "kvv2"
      type  = "kv-v2"
      path  = "webapp/config"

      # Destination Kubernetes secret
      destination = {
        name   = "webapp-secret"
        create = true # VSO creates the secret if it doesn't exist
      }

      # Check for updates every 30 seconds
      refreshAfter = "30s"
    }
  })

  depends_on = [kubectl_manifest.vault_auth_static]
}

# VaultStaticSecret Resource - Elasticsearch Configuration
# Syncs the Elasticsearch secret from Vault to a Kubernetes secret

resource "kubectl_manifest" "elasticsearch_secret" {
  yaml_body = yamlencode({
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultStaticSecret"
    metadata = {
      name      = "elasticsearch-secret"
      namespace = var.namespace
    }
    spec = {
      # Reference to VaultAuth for authentication
      vaultAuthRef = "vault-auth-static"

      # KV v2 mount and path
      mount = "kvv2"
      type  = "kv-v2"
      path  = "elasticsearch/config"

      # Destination Kubernetes secret
      destination = {
        name   = "elasticsearch-secret"
        create = true
      }

      # Check for updates every 30 seconds
      refreshAfter = "30s"
    }
  })

  depends_on = [kubectl_manifest.vault_auth_static]
}
