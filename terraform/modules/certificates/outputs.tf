output "ca_cert_pem" {
  description = "CA certificate in PEM format"
  value       = tls_self_signed_cert.ca.cert_pem
  sensitive   = true
}

output "vault_cert_pem" {
  description = "Vault server certificate in PEM format"
  value       = tls_locally_signed_cert.vault.cert_pem
  sensitive   = true
}

output "vault_key_pem" {
  description = "Vault server private key in PEM format"
  value       = tls_private_key.vault.private_key_pem
  sensitive   = true
}
