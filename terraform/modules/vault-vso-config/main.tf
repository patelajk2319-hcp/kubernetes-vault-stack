# Vault Configuration for Vault Secrets Operator (VSO)
# This module configures Vault to work with VSO:
# - Creates KV v2 secrets engine
# - Adds demo secrets
# - Configures Kubernetes authentication
# - Creates policy for VSO
# - Creates Kubernetes auth role

terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# ------------------------------------------------------------------------------
# KV Secrets Engine
# ------------------------------------------------------------------------------

# Enable KV v2 secrets engine at kvv2/ path
resource "vault_mount" "kvv2" {
  path        = "kvv2"
  type        = "kv"
  options     = { version = "2" }
  description = "KV v2 secrets engine for VSO demo"
}

# Create demo secret for webapp
resource "vault_kv_secret_v2" "webapp" {
  mount = vault_mount.kvv2.path
  name  = "webapp/config"

  data_json = jsonencode({
    username = "static-user"
    password = "static-password"
  })
}

# Create additional demo secret with database credentials
resource "vault_kv_secret_v2" "database" {
  mount = vault_mount.kvv2.path
  name  = "database/config"

  data_json = jsonencode({
    db_host     = "postgres.vault-stack.svc.cluster.local"
    db_port     = "5432"
    db_name     = "myapp"
    db_username = "dbadmin"
    db_password = "sup3rS3cr3t!"
  })
}

# ------------------------------------------------------------------------------
# Kubernetes Authentication
# ------------------------------------------------------------------------------

# Enable Kubernetes authentication method
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

# Configure Kubernetes authentication
resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = var.kubernetes_host
  # For in-cluster configuration, use the service account token
  kubernetes_ca_cert = var.kubernetes_ca_cert
  # Disable local CA JWT verification for simplicity in demo
  disable_local_ca_jwt = var.disable_local_ca_jwt
}

# ------------------------------------------------------------------------------
# Policy for VSO
# ------------------------------------------------------------------------------

# Create policy that allows reading secrets from kvv2/
resource "vault_policy" "vso" {
  name = "vso-policy"

  policy = <<EOT
# Allow reading secrets from kvv2/webapp/*
path "kvv2/data/webapp/*" {
  capabilities = ["read"]
}

# Allow reading secrets from kvv2/database/*
path "kvv2/data/database/*" {
  capabilities = ["read"]
}

# Allow listing secrets
path "kvv2/metadata/*" {
  capabilities = ["list"]
}
EOT
}

# ------------------------------------------------------------------------------
# Kubernetes Auth Role for VSO
# ------------------------------------------------------------------------------

# Create Kubernetes auth role for VSO
resource "vault_kubernetes_auth_backend_role" "vso" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "vso-role"
  bound_service_account_names      = var.vso_service_accounts
  bound_service_account_namespaces = [var.kubernetes_namespace]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.vso.name]
  audience                         = "vault"
}
