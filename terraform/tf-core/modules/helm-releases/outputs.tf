output "vault_status" {
  description = "Status of the Vault Helm release"
  value       = helm_release.vault.status
}

output "namespace" {
  description = "Namespace where resources are deployed"
  value       = var.namespace
}
