# ============================================================================
# Vault Database Secrets Engine Configuration
# ============================================================================

# Database Secrets Engine Mount
# Enables Vault's database secrets engine at the "database/" path

resource "vault_mount" "database" {
  path        = "database"
  type        = "database"
  description = "Database secrets engine for dynamic Elasticsearch credentials"
}

# Elasticsearch Database Connection
# Configures Vault's connection to Elasticsearch for dynamic credential generation
resource "vault_database_secret_backend_connection" "elasticsearch" {
  backend       = vault_mount.database.path
  name          = "elasticsearch"
  allowed_roles = [var.db_role_name]

  elasticsearch {
    # URL to Elasticsearch (Podman on host machine, accessible from minikube)
    url = var.elasticsearch_url

    # Admin credentials for creating/deleting dynamic users
    username = var.elasticsearch_username
    password = var.elasticsearch_password

    # Skip TLS verification for demo (self-signed certs)
    insecure = true
  }

  # Test the connection on terraform apply
  verify_connection = true
}

# Elasticsearch Database Role
resource "vault_database_secret_backend_role" "elasticsearch" {
  backend = vault_mount.database.path
  name    = var.db_role_name
  db_name = vault_database_secret_backend_connection.elasticsearch.name

  # Default TTL: initial lifetime of credentials (5 minutes)
  default_ttl = var.default_ttl

  # After this, VSO must request NEW credentials
  max_ttl = var.max_ttl

  creation_statements = [
    jsonencode({
      elasticsearch_roles = ["vault_es_role", "kibana_admin"]
    })
  ]
}

# Create Vault policy
resource "vault_policy" "elasticsearch_dynamic" {
  name   = "elasticsearch-dynamic-policy"
  policy = data.vault_policy_document.elasticsearch_dynamic.hcl
}

# ============================================================================
# Kubernetes Authentication for VSO
# ============================================================================

# Update existing Kubernetes auth role to include dynamic credentials policy
# Note: This assumes kubernetes auth is already configured by tf-vso
resource "vault_kubernetes_auth_backend_role" "elasticsearch_dynamic_role" {
  backend   = "kubernetes"
  role_name = "elasticsearch-dynamic-role"
  bound_service_account_names = [
    kubernetes_service_account.dynamic_webapp.metadata[0].name,
    "vault-secrets-operator-controller-manager"
  ]
  bound_service_account_namespaces = [var.namespace]
  token_policies                   = [vault_policy.elasticsearch_dynamic.name]
  token_ttl                        = 3600
  # Required audience claim in JWT token
  # Format: <namespace>-<app>-<purpose>
  audience = "vault-stack-dynamic-webapp-vault-auth"
}

# ============================================================================
# Kubernetes Service Account
# ============================================================================

# This service account is used by the webapp to authenticate to Vault
resource "kubernetes_service_account" "dynamic_webapp" {
  metadata {
    name      = "elk-dynamic-webapp-svc-acc"
    namespace = var.namespace
  }
}

# ============================================================================
# Kubernetes Resources for VSO Dynamic Secrets
# ============================================================================

# VaultAuth Resource
# Defines how Vault Secrets Operator (VSO) authenticates to Vault for dynamic secrets
#
# This creates a VaultAuth CRD that:
# - Uses Kubernetes auth method (service account tokens)
# - References the shared VaultConnection (created by tf-vso module)
# - Authenticates as the elasticsearch-dynamic-role
# - Allows VSO to request dynamic Elasticsearch credentials from Vault
resource "kubectl_manifest" "vault_auth_dynamic" {
  yaml_body = yamlencode({
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultAuth"
    metadata = {
      name      = "vault-auth-dynamic"
      namespace = var.namespace
    }
    spec = {
      # Reference to the shared VaultConnection created by tf-vso
      vaultConnectionRef = "vault-connection"

      # Use Kubernetes auth method
      method = "kubernetes"
      mount  = "kubernetes"

      kubernetes = {
        # Vault role that grants access to database/creds/* path
        role = "elasticsearch-dynamic-role"

        # Service account that will authenticate to Vault
        serviceAccount = kubernetes_service_account.dynamic_webapp.metadata[0].name

        # Audience claim for the JWT token
        # Must match the audience configured in the Vault role
        audiences = ["vault-stack-dynamic-webapp-vault-auth"]
      }
    }
  })

  # Ensure the Vault role exists before creating this auth resource
  depends_on = [vault_kubernetes_auth_backend_role.elasticsearch_dynamic_role]
}

# VaultDynamicSecret Resource
# Generates dynamic, time-limited Elasticsearch credentials from Vault's database secrets engine
#
# This creates a VaultDynamicSecret CRD that:
# - Requests credentials from Vault's database secrets engine every 60 seconds (lease renewal)
# - Generates NEW credentials when the lease can no longer be renewed (every 5 minutes with current config)
# - Automatically syncs credentials to a Kubernetes secret
# - Revokes old credentials when new ones are generated
# - Updates mounted files in running pods 

resource "kubectl_manifest" "elasticsearch_dynamic_secret" {
  yaml_body = yamlencode({
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultDynamicSecret"
    metadata = {
      name      = "elasticsearch-dynamic-secret"
      namespace = var.namespace
    }
    spec = {
      # Reference to the VaultAuth resource for authentication
      vaultAuthRef = "vault-auth-dynamic"

      # Path to the database secrets engine mount
      mount = vault_mount.database.path

      # Path to request credentials (database/creds/elasticsearch-role)
      path = "creds/${vault_database_secret_backend_role.elasticsearch.name}"

      # Destination Kubernetes secret configuration
      destination = {
        # Name of the Kubernetes secret to create/update
        name = "elasticsearch-dynamic-secret"

        # VSO will create the secret if it doesn't exist
        create = true
      }

      # How often to check and renew the lease (60 seconds)
      # Note: This renews the SAME credentials, not generate new ones
      # New credentials are only generated when max_ttl is reached
      refreshAfter = "60s"

      # Automatically revoke credentials in Vault when they're rotated
      revoke = true
    }
  })

  depends_on = [
    kubectl_manifest.vault_auth_dynamic,
    vault_database_secret_backend_role.elasticsearch
  ]
}

# ============================================================================
# Demo Application Deployment
# ============================================================================

# Deploy demo application deployment that uses dynamic Elasticsearch credentials
resource "kubectl_manifest" "elk_dynamic_webapp_deployment" {
  yaml_body = local.webapp_yaml_docs[0]

  depends_on = [kubectl_manifest.elasticsearch_dynamic_secret]
}

# Deploy demo application service
resource "kubectl_manifest" "elk_dynamic_webapp_service" {
  yaml_body = local.webapp_yaml_docs[1]

  depends_on = [kubectl_manifest.elk_dynamic_webapp_deployment]
}
