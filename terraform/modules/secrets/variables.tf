variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "ca_cert_pem" {
  description = "CA certificate in PEM format"
  type        = string
  sensitive   = true
}

variable "vault_cert_pem" {
  description = "Vault certificate in PEM format"
  type        = string
  sensitive   = true
}

variable "vault_key_pem" {
  description = "Vault private key in PEM format"
  type        = string
  sensitive   = true
}

variable "vault_license_b64" {
  description = "Vault license in base64"
  type        = string
  sensitive   = true
}
