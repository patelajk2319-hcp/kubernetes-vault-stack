variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "vault-stack"
}

variable "webapp_username" {
  description = "Demo webapp username"
  type        = string
  default     = "demo-user"
}

variable "webapp_password" {
  description = "Demo webapp password"
  type        = string
  default     = "demo-password"
  sensitive   = true
}

variable "elasticsearch_host" {
  description = "Elasticsearch host"
  type        = string
  default     = "host.minikube.internal"
}

variable "elasticsearch_port" {
  description = "Elasticsearch port"
  type        = string
  default     = "9200"
}

variable "elasticsearch_protocol" {
  description = "Elasticsearch protocol"
  type        = string
  default     = "https"
}

variable "elasticsearch_username" {
  description = "Elasticsearch username"
  type        = string
  default     = "elastic"
}

variable "elasticsearch_password" {
  description = "Elasticsearch password"
  type        = string
  default     = "password123"
  sensitive   = true
}

variable "elasticsearch_index" {
  description = "Elasticsearch index name"
  type        = string
  default     = "demo-index"
}
