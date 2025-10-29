# ============================================================================
# Vault Database Secrets Engine Configuration
# ============================================================================

# Database Secrets Engine Mount
# Enables Vault's database secrets engine at the "database/" path
#
# The database secrets engine generates dynamic credentials with:
# - Time-limited access (TTL-based expiration)
# - Automatic credential rotation
# - Automatic revocation when credentials expire
# - Audit logging of all credential access
#
# This is the foundation for zero-trust credential management where:
# - No long-lived credentials exist
# - Each application gets unique, short-lived credentials
# - Credentials are automatically rotated and revoked
resource "vault_mount" "database" {
  path        = "database"
  type        = "database"
  description = "Database secrets engine for dynamic Elasticsearch credentials"
}

# Elasticsearch Database Connection
# Configures Vault's connection to Elasticsearch for dynamic credential generation
#
# This resource:
# - Connects to Elasticsearch running in Podman on the host (host.minikube.internal:9200)
# - Uses admin credentials (elastic user) to create/delete dynamic users
# - Verifies the connection on apply to ensure Elasticsearch is accessible
# - Restricts which Vault roles can use this connection (allowed_roles)
#
# Security note:
# - insecure=true is used because we're using self-signed certs in this demo
# - For production, use proper TLS verification with the CA certificate
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
    # For production, set to false and provide ca_cert
    insecure = true
  }

  # Test the connection on terraform apply
  verify_connection = true
}

# Elasticsearch Database Role
# Defines the template for dynamically generated Elasticsearch users
#
# This role specifies:
# - TTL settings (how long credentials are valid)
# - Elasticsearch permissions (indices, cluster, applications, Kibana)
# - What Vault will execute when creating/deleting users
#
# TTL Behaviour:
# - default_ttl (5 minutes): Initial lifetime of credentials
# - max_ttl (5 minutes): Maximum time credentials can be renewed
# - VSO renews every 60 seconds until max_ttl is reached
# - After max_ttl, VSO must request NEW credentials (rotation)
#
# Permissions granted to dynamic users:
# - Full index operations (read, write, create, delete, monitor)
# - Kibana UI access (all privileges on kibana-.kibana app)
# - Cluster monitoring capabilities
#
# Use case: Demo webapp and manual Kibana login
resource "vault_database_secret_backend_role" "elasticsearch" {
  backend = vault_mount.database.path
  name    = var.db_role_name
  db_name = vault_database_secret_backend_connection.elasticsearch.name

  # Default TTL: initial lifetime of credentials (5 minutes)
  default_ttl = var.default_ttl

  # Max TTL: maximum time credentials can exist (5 minutes)
  # After this, VSO must request NEW credentials
  max_ttl = var.max_ttl

  # Elasticsearch role definition (JSON format)
  # Defines permissions for dynamically created users
  creation_statements = [
    jsonencode({
      elasticsearch_role_definition = {
        # Index permissions - access to all indices
        indices = [
          {
            names = ["*"] # All indices
            privileges = [
              "read",                # Read documents and query
              "write",               # Index/update/delete documents
              "create_index",        # Create new indices
              "delete_index",        # Delete indices
              "view_index_metadata", # View index settings/mappings
              "monitor"              # View index statistics
            ]
          }
        ]

        # Application permissions - Kibana UI access
        applications = [
          {
            application = "kibana-.kibana" # Kibana system indices
            privileges  = ["all"]          # Full Kibana UI access
            resources   = ["*"]            # All Kibana spaces
          }
        ]

        # Cluster permissions - monitoring and management
        cluster = [
          "monitor",                # View cluster health/stats
          "manage_index_templates", # Manage index templates
          "monitor_ml",             # View ML jobs
          "monitor_watcher",        # View watchers
          "monitor_transform"       # View transforms
        ]

        # Run-as permissions (none - users cannot impersonate others)
        run_as = []
      }
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
  backend                          = "kubernetes"
  role_name                        = "elasticsearch-dynamic-role"
  bound_service_account_names      = ["default", "vault-secrets-operator-controller-manager"]
  bound_service_account_namespaces = [var.namespace]
  token_policies                   = [vault_policy.elasticsearch_dynamic.name]
  token_ttl                        = 3600
  audience                         = "vault"
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
#
# The default service account is used, which VSO controller injects into the pod
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

      # Use Kubernetes auth method (service account tokens)
      method = "kubernetes"
      mount  = "kubernetes"

      kubernetes = {
        # Vault role that grants access to database/creds/* path
        role = "elasticsearch-dynamic-role"

        # Service account that will authenticate to Vault
        serviceAccount = "default"

        # Audience claim for the JWT token
        audiences = ["vault"]
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
# - Updates mounted files in running pods (zero-downtime rotation)
#
# Credential lifecycle:
# - Every 60s: VSO renews the lease (same username/password)
# - Every 5min: Vault refuses renewal (max_ttl reached), VSO requests new credentials
# - Immediately: Kubernetes updates the secret and mounted files in pods
# - Pods read fresh credentials from /vault/secrets/username and /vault/secrets/password
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
      # This ensures old credentials are immediately invalidated
      revoke = true

      # NOTE: rolloutRestartTargets removed for zero-downtime rotation
      # Pods use volume mounts which are auto-updated by Kubernetes
      # Apps read from /vault/secrets/* files on every request
    }
  })

  # Ensure dependencies are created first
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
