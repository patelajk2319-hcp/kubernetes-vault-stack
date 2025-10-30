output "kubernetes_auth_path" {
  description = "Path where Kubernetes auth backend is mounted"
  value       = vault_auth_backend.kubernetes.path
}

output "vault_connection_name" {
  description = "Name of the VaultConnection CRD (shared resource)"
  value       = "vault-connection"
}
