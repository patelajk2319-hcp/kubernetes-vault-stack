variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "vault-stack"
}

variable "vault_service_name" {
  description = "Name of the Vault service in Kubernetes"
  type        = string
  default     = "vault-stack"
}
