output "ca_cert_path" {
  description = "Path to CA certificate"
  value       = local_file.ca_cert.filename
}

output "elasticsearch_cert_path" {
  description = "Path to Elasticsearch certificate"
  value       = local_file.elasticsearch_cert.filename
}

output "kibana_cert_path" {
  description = "Path to Kibana certificate"
  value       = local_file.kibana_cert.filename
}

output "fleet_server_cert_path" {
  description = "Path to Fleet Server certificate"
  value       = local_file.fleet_server_cert.filename
}

output "validity_days" {
  description = "Certificate validity period in days"
  value       = var.cert_validity_days
}
