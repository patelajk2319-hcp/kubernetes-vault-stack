output "kvv2_mount_path" {
  description = "Path where KV v2 secrets engine is mounted"
  value       = vault_mount.kvv2.path
}

output "webapp_secret_path" {
  description = "Path to webapp configuration secret in Vault"
  value       = "kvv2/data/webapp/config"
}

output "elasticsearch_secret_path" {
  description = "Path to Elasticsearch configuration secret in Vault"
  value       = "kvv2/data/elasticsearch/config"
}

output "static_secrets_policy_name" {
  description = "Name of the Vault policy for static secrets"
  value       = vault_policy.static_secrets_policy.name
}

output "static_secrets_role_name" {
  description = "Name of the Kubernetes auth role for static secrets"
  value       = vault_kubernetes_auth_backend_role.static_secrets_role.role_name
}
