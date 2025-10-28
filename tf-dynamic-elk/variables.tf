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

variable "elasticsearch_url" {
  description = "Elasticsearch URL (Podman on host machine)"
  type        = string
  default     = "https://host.minikube.internal:9200"
}

variable "elasticsearch_username" {
  description = "Elasticsearch admin username"
  type        = string
  default     = "elastic"
}

variable "elasticsearch_password" {
  description = "Elasticsearch admin password (from elk-compose.yml)"
  type        = string
  default     = "password123"
  sensitive   = true
}

variable "db_role_name" {
  description = "Name of the database role in Vault"
  type        = string
  default     = "elasticsearch-role"
}

variable "default_ttl" {
  description = "Default TTL for dynamic credentials"
  type        = number
  default     = 300 # 5 minutes
}

variable "max_ttl" {
  description = "Maximum TTL for dynamic credentials"
  type        = number
  default     = 3600 # 1 hour
}
