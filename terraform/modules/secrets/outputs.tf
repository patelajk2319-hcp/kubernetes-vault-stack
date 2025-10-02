output "vault_certs_secret_name" {
  description = "Name of the Vault certificates secret"
  value       = kubernetes_secret.vault_certs.metadata[0].name
}

output "elasticsearch_certs_secret_name" {
  description = "Name of the Elasticsearch certificates secret"
  value       = kubernetes_secret.elasticsearch_certs.metadata[0].name
}

output "vault_license_secret_name" {
  description = "Name of the Vault license secret"
  value       = kubernetes_secret.vault_license.metadata[0].name
}
