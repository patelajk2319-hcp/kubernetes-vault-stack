# ============================================================================
# Data Sources - Read Elasticsearch CA certificate from local filesystem
# ============================================================================

# Read CA certificate from local certs directory (used by Podman)
data "local_file" "elasticsearch_ca_cert" {
  filename = abspath("${path.module}/../certs/ca/ca.crt")
}

# ============================================================================
# Vault Database Secrets Engine Configuration
# ============================================================================

# Enable the database secrets engine
resource "vault_mount" "database" {
  path        = "database"
  type        = "database"
  description = "Database secrets engine for dynamic Elasticsearch credentials"
}

# Configure Elasticsearch database connection
resource "vault_database_secret_backend_connection" "elasticsearch" {
  backend       = vault_mount.database.path
  name          = "elasticsearch"
  allowed_roles = [var.db_role_name]

  elasticsearch {
    url      = var.elasticsearch_url
    username = var.elasticsearch_username
    password = var.elasticsearch_password
    insecure = true  # Skip TLS verification for demo with self-signed certs
  }

  verify_connection = true
}

# Create a database role for Elasticsearch
resource "vault_database_secret_backend_role" "elasticsearch" {
  backend     = vault_mount.database.path
  name        = var.db_role_name
  db_name     = vault_database_secret_backend_connection.elasticsearch.name
  default_ttl = var.default_ttl
  max_ttl     = var.max_ttl

  creation_statements = [
    jsonencode({
      elasticsearch_role_definition = {
        indices = [
          {
            names      = ["*"]
            privileges = ["read", "write", "create_index", "delete_index", "view_index_metadata", "monitor"]
          }
        ]
        applications = [
          {
            application = "kibana-.kibana"
            privileges  = ["all"]
            resources   = ["*"]
          }
        ]
        cluster = ["monitor", "manage_index_templates", "monitor_ml", "monitor_watcher", "monitor_transform"]
        run_as  = []
      }
    })
  ]
}

# ============================================================================
# Vault Policy for Dynamic Credentials
# ============================================================================

# Create policy document for reading dynamic credentials
data "vault_policy_document" "elasticsearch_dynamic" {
  rule {
    path         = "${vault_mount.database.path}/creds/${vault_database_secret_backend_role.elasticsearch.name}"
    capabilities = ["read"]
    description  = "Allow reading dynamic Elasticsearch credentials"
  }

  rule {
    path         = "${vault_mount.database.path}/creds/*"
    capabilities = ["list"]
    description  = "Allow listing database credential paths"
  }
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

# VaultAuth - defines how VSO authenticates to Vault for dynamic secrets
resource "kubectl_manifest" "vault_auth_dynamic" {
  yaml_body = <<YAML
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: vault-auth-dynamic
  namespace: ${var.namespace}
spec:
  vaultConnectionRef: vault-connection
  method: kubernetes
  mount: kubernetes
  kubernetes:
    role: elasticsearch-dynamic-role
    serviceAccount: default
    audiences:
      - vault
YAML

  depends_on = [vault_kubernetes_auth_backend_role.elasticsearch_dynamic_role]
}

# VaultDynamicSecret - generates dynamic Elasticsearch credentials
resource "kubectl_manifest" "elasticsearch_dynamic_secret" {
  yaml_body = <<YAML
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultDynamicSecret
metadata:
  name: elasticsearch-dynamic-secret
  namespace: ${var.namespace}
spec:
  vaultAuthRef: vault-auth-dynamic
  mount: ${vault_mount.database.path}
  path: creds/${vault_database_secret_backend_role.elasticsearch.name}
  destination:
    name: elasticsearch-dynamic-secret
    create: true
  refreshAfter: 60s
  revoke: true
YAML

  depends_on = [
    kubectl_manifest.vault_auth_dynamic,
    vault_database_secret_backend_role.elasticsearch
  ]
}

# ============================================================================
# Demo Application Deployment
# ============================================================================

# Split the YAML file into separate resources (filter out empty strings)
locals {
  webapp_yaml_raw  = split("---", file("${path.module}/../k8s/elk-dynamic/00_webapp-deployment.yaml"))
  webapp_yaml_docs = [for doc in local.webapp_yaml_raw : trimspace(doc) if trimspace(doc) != ""]
}

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
