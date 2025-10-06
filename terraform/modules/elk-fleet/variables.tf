# Variables for ELK Fleet Module

variable "namespace" {
  description = "Kubernetes namespace for Fleet and Agent deployment"
  type        = string
  default     = "vault-stack"
}

variable "fleet_server_version" {
  description = "Version of Fleet Server and Elastic Agent"
  type        = string
  default     = "8.12.0"
}

variable "audit_logs_storage_size" {
  description = "Size of the PVC for Vault audit logs"
  type        = string
  default     = "5Gi"
}

variable "elasticsearch_host" {
  description = "Elasticsearch host URL"
  type        = string
  default     = "https://elasticsearch-es-http.vault-stack.svc:9200"
}

variable "kibana_host" {
  description = "Kibana host URL"
  type        = string
  default     = "https://kibana-kb-http.vault-stack.svc:5601"
}
