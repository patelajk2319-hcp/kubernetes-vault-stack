output "database_mount_path" {
  description = "Path where the database secrets engine is mounted"
  value       = vault_mount.database.path
}

output "database_role_name" {
  description = "Name of the Elasticsearch database role"
  value       = vault_database_secret_backend_role.elasticsearch.name
}

output "dynamic_secret_path" {
  description = "Path to read dynamic credentials from Vault"
  value       = "${vault_mount.database.path}/creds/${vault_database_secret_backend_role.elasticsearch.name}"
}
