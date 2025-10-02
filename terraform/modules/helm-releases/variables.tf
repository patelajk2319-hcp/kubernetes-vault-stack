variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "release_name" {
  description = "Helm release name"
  type        = string
}

variable "chart_path" {
  description = "Path to the Helm chart"
  type        = string
}

variable "vault_license_b64" {
  description = "Vault license in base64"
  type        = string
  sensitive   = true
}

variable "eck_operator_version" {
  description = "ECK operator chart version"
  type        = string
  default     = "2.9.0"
}
