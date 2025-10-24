# Outputs for Vault VSO Configuration Module

output "kvv2_mount_path" {
  description = "Path where KV v2 secrets engine is mounted"
  value       = vault_mount.kvv2.path
}

output "kubernetes_auth_path" {
  description = "Path where Kubernetes auth method is mounted"
  value       = vault_auth_backend.kubernetes.path
}

output "vso_role_name" {
  description = "Name of the Kubernetes auth role for VSO"
  value       = vault_kubernetes_auth_backend_role.vso.role_name
}

output "vso_policy_name" {
  description = "Name of the policy for VSO"
  value       = vault_policy.vso.name
}

output "webapp_secret_path" {
  description = "Path to the webapp secret in Vault"
  value       = "${vault_mount.kvv2.path}/data/${vault_kv_secret_v2.webapp.name}"
}

output "database_secret_path" {
  description = "Path to the database secret in Vault"
  value       = "${vault_mount.kvv2.path}/data/${vault_kv_secret_v2.database.name}"
}
