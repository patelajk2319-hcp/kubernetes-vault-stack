# Variables for Vault VSO Configuration Module

variable "kubernetes_host" {
  description = "Kubernetes API server address for Vault authentication"
  type        = string
  default     = "https://kubernetes.default.svc.cluster.local"
}

variable "kubernetes_ca_cert" {
  description = "Kubernetes CA certificate for Vault authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "disable_local_ca_jwt" {
  description = "Disable local CA JWT verification (set to true for in-cluster Vault)"
  type        = bool
  default     = false
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace where VSO will run"
  type        = string
  default     = "vault-stack"
}

variable "vso_service_accounts" {
  description = "List of service accounts that VSO will use"
  type        = list(string)
  default     = ["default", "vault-secrets-operator-controller-manager"]
}
