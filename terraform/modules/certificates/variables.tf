variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "common_name" {
  description = "Common name for the certificate"
  type        = string
}

variable "validity_hours" {
  description = "Certificate validity in hours"
  type        = number
}
