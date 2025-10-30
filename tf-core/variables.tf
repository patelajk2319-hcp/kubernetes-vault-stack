variable "namespace" {
  description = "Kubernetes namespace for the Vault stack"
  type        = string
  default     = "vault-stack"
}

variable "vault_license_file" {
  description = "Path to Vault Enterprise license file"
  type        = string
  default     = "../licenses/vault-enterprise/license.lic"
}

variable "cert_common_name" {
  description = "Common name for TLS certificates"
  type        = string
  default     = "vault.vault-stack.svc.cluster.local"
}

variable "cert_validity_hours" {
  description = "Validity period for TLS certificates in hours"
  type        = number
  default     = 8760 # 1 year
}
