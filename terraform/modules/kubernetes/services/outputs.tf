output "vault_nodeport_name" {
  description = "Name of the Vault NodePort service"
  value       = kubernetes_service.vault_nodeport.metadata[0].name
}

output "grafana_nodeport_name" {
  description = "Name of the Grafana NodePort service"
  value       = kubernetes_service.grafana_nodeport.metadata[0].name
}

output "prometheus_nodeport_name" {
  description = "Name of the Prometheus NodePort service"
  value       = kubernetes_service.prometheus_nodeport.metadata[0].name
}

output "kibana_nodeport_name" {
  description = "Name of the Kibana NodePort service"
  value       = kubernetes_service.kibana_nodeport.metadata[0].name
}

output "elasticsearch_nodeport_name" {
  description = "Name of the Elasticsearch NodePort service"
  value       = kubernetes_service.elasticsearch_nodeport.metadata[0].name
}
