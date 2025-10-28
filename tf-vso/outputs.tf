output "kvv2_mount_path" {
  description = "Path where KV v2 secrets engine is mounted"
  value       = vault_mount.kvv2.path
}

output "kubernetes_auth_path" {
  description = "Path where Kubernetes auth method is enabled"
  value       = vault_auth_backend.kubernetes.path
}

output "vso_policy_name" {
  description = "Name of the VSO policy"
  value       = vault_policy.vso_policy.name
}

output "vso_role_name" {
  description = "Name of the Kubernetes auth role for VSO"
  value       = vault_kubernetes_auth_backend_role.vso_role.role_name
}

output "webapp_secret_path" {
  description = "Path to webapp secret in Vault"
  value       = "${vault_mount.kvv2.path}/data/${vault_kv_secret_v2.webapp_config.name}"
}

output "elasticsearch_secret_path" {
  description = "Path to Elasticsearch secret in Vault"
  value       = "${vault_mount.kvv2.path}/data/${vault_kv_secret_v2.elasticsearch_config.name}"
}
