# Static Elasticsearch Secrets Demo

# KV v2 mount
resource "vault_mount" "kvv2" {
  path = "kvv2"
  type = "kv"
  options = {
    version = "2"
  }
  description = "KV v2 secrets engine for static secrets"
}

# Webapp configuration secret
resource "vault_kv_secret_v2" "webapp_config" {
  mount = vault_mount.kvv2.path
  name  = "webapp/config"

  data_json = jsonencode({
    username = var.webapp_username
    password = var.webapp_password
  })

  depends_on = [vault_mount.kvv2]
}

# Elasticsearch configuration secret
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
    es_url      = "${var.elasticsearch_protocol}://${var.elasticsearch_host}:${var.elasticsearch_port}"
  })

  depends_on = [vault_mount.kvv2]
}

# Service account for static secrets demo
resource "kubernetes_service_account" "static_webapp" {
  metadata {
    name      = "elk-static-webapp-svc-acc"
    namespace = var.namespace
  }
}

# Vault policy for static secrets
resource "vault_policy" "static_secrets_policy" {
  name   = "static-secrets-policy"
  policy = data.vault_policy_document.static_secrets_policy.hcl
}

# Kubernetes auth role for static secrets
resource "vault_kubernetes_auth_backend_role" "static_secrets_role" {
  backend                          = "kubernetes"
  role_name                        = "static-secrets-role"
  bound_service_account_names      = [kubernetes_service_account.static_webapp.metadata[0].name, "vault-secrets-operator-controller-manager"]
  bound_service_account_namespaces = [var.namespace]
  token_policies                   = [vault_policy.static_secrets_policy.name]
  token_ttl                        = 3600
  audience                         = "vault-stack-static-webapp-vault-auth"
}

# VaultAuth resource for static secrets
resource "kubernetes_manifest" "vault_auth_static" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultAuth"
    metadata = {
      name      = "vault-auth-static"
      namespace = var.namespace
    }
    spec = {
      vaultConnectionRef = "vault-connection"
      method             = "kubernetes"
      mount              = "kubernetes"

      kubernetes = {
        role           = "static-secrets-role"
        serviceAccount = kubernetes_service_account.static_webapp.metadata[0].name
        audiences      = ["vault-stack-static-webapp-vault-auth"]
      }
    }
  }

  depends_on = [vault_kubernetes_auth_backend_role.static_secrets_role]
}

# VaultStaticSecret for webapp config
resource "kubernetes_manifest" "webapp_secret" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultStaticSecret"
    metadata = {
      name      = "webapp-secret"
      namespace = var.namespace
    }
    spec = {
      vaultAuthRef = "vault-auth-static"
      mount        = "kvv2"
      type         = "kv-v2"
      path         = "webapp/config"

      destination = {
        name   = "webapp-secret"
        create = true
      }

      refreshAfter = "30s"
    }
  }

  depends_on = [kubernetes_manifest.vault_auth_static]
}

# VaultStaticSecret for Elasticsearch config
resource "kubernetes_manifest" "elasticsearch_secret" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultStaticSecret"
    metadata = {
      name      = "elasticsearch-secret"
      namespace = var.namespace
    }
    spec = {
      vaultAuthRef = "vault-auth-static"
      mount        = "kvv2"
      type         = "kv-v2"
      path         = "elasticsearch/config"

      destination = {
        name   = "elasticsearch-secret"
        create = true
      }

      refreshAfter = "30s"
    }
  }

  depends_on = [kubernetes_manifest.vault_auth_static]
}
