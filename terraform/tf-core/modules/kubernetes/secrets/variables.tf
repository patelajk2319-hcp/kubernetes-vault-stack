variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "vault_cert_pem" {
  description = "Vault certificate PEM"
  type        = string
  sensitive   = true
}

variable "vault_key_pem" {
  description = "Vault private key PEM"
  type        = string
  sensitive   = true
}

variable "ca_cert_pem" {
  description = "CA certificate PEM"
  type        = string
  sensitive   = true
}

variable "vault_license" {
  description = "Vault Enterprise license"
  type        = string
  sensitive   = true
}
