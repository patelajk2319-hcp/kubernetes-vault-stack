# Outputs for ELK Fleet Module

output "fleet_server_service" {
  description = "Fleet Server service name"
  value       = "fleet-server.${var.namespace}.svc"
}

output "fleet_server_url" {
  description = "Fleet Server URL"
  value       = "http://fleet-server.${var.namespace}.svc:8220"
}

output "audit_logs_pvc_name" {
  description = "Name of the Vault audit logs PVC"
  value       = "vault-audit-logs"
}
