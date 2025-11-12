# Vault Database Secrets Engine for dynamic Elasticsearch credentials

resource "vault_mount" "database" {
  path        = "database"
  type        = "database"
  description = "Database secrets engine for dynamic Elasticsearch credentials"
}

resource "vault_database_secret_backend_connection" "elasticsearch" {
  backend       = vault_mount.database.path
  name          = "elasticsearch"
  allowed_roles = [var.db_role_name]

  elasticsearch {
    url      = var.elasticsearch_url
    username = var.elasticsearch_username
    password = var.elasticsearch_password
    insecure = true
  }

  verify_connection = true
}

resource "vault_database_secret_backend_role" "elasticsearch" {
  backend = vault_mount.database.path
  name    = var.db_role_name
  db_name = vault_database_secret_backend_connection.elasticsearch.name

  default_ttl = var.default_ttl
  max_ttl     = var.max_ttl

  creation_statements = [
    jsonencode({
      elasticsearch_roles = ["vault_es_role", "kibana_admin"]
    })
  ]
}

resource "vault_policy" "elasticsearch_dynamic" {
  name   = "elasticsearch-dynamic-policy"
  policy = data.vault_policy_document.elasticsearch_dynamic.hcl
}

# Kubernetes authentication for VSO

resource "vault_kubernetes_auth_backend_role" "elasticsearch_dynamic_role" {
  backend   = "kubernetes"
  role_name = "elasticsearch-dynamic-role"

  bound_service_account_names      = [kubernetes_service_account.dynamic_webapp.metadata[0].name]
  bound_service_account_namespaces = [var.namespace]
  token_policies                   = [vault_policy.elasticsearch_dynamic.name]
  token_ttl                        = 3600

  audience = "vault-stack-dynamic-webapp-vault-auth"
}

resource "kubernetes_service_account" "dynamic_webapp" {
  metadata {
    name      = "elk-dynamic-webapp-svc-acc"
    namespace = var.namespace
  }
}

# VSO resources for dynamic secrets

resource "kubernetes_manifest" "vault_auth_dynamic" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultAuth"
    metadata = {
      name      = "vault-auth-dynamic"
      namespace = var.namespace
    }
    spec = {
      vaultConnectionRef = "vault-connection"
      method             = "kubernetes"
      mount              = "kubernetes"

      kubernetes = {
        role           = "elasticsearch-dynamic-role"
        serviceAccount = kubernetes_service_account.dynamic_webapp.metadata[0].name
        audiences      = ["vault-stack-dynamic-webapp-vault-auth"]
      }
    }
  }

  depends_on = [vault_kubernetes_auth_backend_role.elasticsearch_dynamic_role]
}

resource "kubernetes_manifest" "elasticsearch_dynamic_secret" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultDynamicSecret"
    metadata = {
      name      = "elasticsearch-dynamic-secret"
      namespace = var.namespace
    }
    spec = {
      vaultAuthRef = "vault-auth-dynamic"
      mount        = vault_mount.database.path
      path         = "creds/${vault_database_secret_backend_role.elasticsearch.name}"

      destination = {
        name   = "elasticsearch-dynamic-secret"
        create = true
      }

      refreshAfter = "60s"
      revoke       = true
    }
  }

  depends_on = [
    kubernetes_manifest.vault_auth_dynamic,
    vault_database_secret_backend_role.elasticsearch
  ]
}
