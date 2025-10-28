variable "namespace" {
  description = "Kubernetes namespace for VSO demo"
  type        = string
  default     = "vault-stack"
}

variable "vault_service_name" {
  description = "Name of the Vault service in Kubernetes"
  type        = string
  default     = "vault-stack"
}

variable "webapp_username" {
  description = "Initial username for webapp demo"
  type        = string
  default     = "static-user"
}

variable "webapp_password" {
  description = "Initial password for webapp demo"
  type        = string
  default     = "static-password"
  sensitive   = true
}

variable "elasticsearch_host" {
  description = "Elasticsearch host for demo"
  type        = string
  default     = "host.minikube.internal"
}

variable "elasticsearch_port" {
  description = "Elasticsearch port"
  type        = string
  default     = "9200"
}

variable "elasticsearch_protocol" {
  description = "Elasticsearch protocol (http/https)"
  type        = string
  default     = "http"
}

variable "elasticsearch_username" {
  description = "Elasticsearch username"
  type        = string
  default     = "elastic"
}

variable "elasticsearch_password" {
  description = "Elasticsearch password"
  type        = string
  default     = "changeme"
  sensitive   = true
}

variable "elasticsearch_index" {
  description = "Elasticsearch index for Vault audit logs"
  type        = string
  default     = "vault-audit-logs"
}
