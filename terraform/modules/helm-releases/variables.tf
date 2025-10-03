variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "vault_license_b64" {
  description = "Vault license in base64"
  type        = string
  sensitive   = true
}
