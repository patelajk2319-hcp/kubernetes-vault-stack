output "namespace" {
  description = "Kubernetes namespace for the Vault stack"
  value       = var.namespace
}

output "vault_status" {
  description = "Status of the Vault Helm release"
  value       = module.helm_releases.vault_status
}

output "vault_certs_secret" {
  description = "Name of the Vault certificates secret"
  value       = module.kubernetes_secrets.vault_certs_name
}

output "service_urls" {
  description = "Service URLs via NodePort"
  value = {
    vault         = "http://localhost:30200"
    grafana       = "http://localhost:30300"
    prometheus    = "http://localhost:30090"
    kibana        = "http://localhost:30601"
    elasticsearch = "https://localhost:30920"
  }
}

output "next_steps" {
  description = "Instructions for next steps"
  value       = <<-EOT

    Deployment complete!

    Services are accessible via NodePort:
    - Vault UI:         http://localhost:30200/ui
    - Grafana:          http://localhost:30300
    - Prometheus:       http://localhost:30090
    - Kibana:           http://localhost:30601
    - Elasticsearch:    https://localhost:30920

    Next steps:

    1. Set up port forwarding to localhost:
       kubectl port-forward -n vault-stack svc/vault-nodeport 8200:8200 &
       kubectl port-forward -n vault-stack svc/grafana-nodeport 3000:3000 &
       kubectl port-forward -n vault-stack svc/prometheus-nodeport 9090:9090 &
       kubectl port-forward -n vault-stack svc/kibana-nodeport 5601:5601 &
       kubectl port-forward -n vault-stack svc/elasticsearch-nodeport 9200:9200 &

    2. Initialise Vault:
       task init

    3. Unseal Vault:
       task unseal

    4. View access information:
       task info
  EOT
}
