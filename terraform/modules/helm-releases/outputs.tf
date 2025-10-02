output "vault_stack_status" {
  description = "Status of the Vault stack Helm release"
  value       = helm_release.vault_stack.status
}

output "namespace" {
  description = "Namespace where resources are deployed"
  value       = var.namespace
}
