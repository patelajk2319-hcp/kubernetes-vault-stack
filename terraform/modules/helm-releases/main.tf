# Add required Helm repositories
resource "helm_release" "vault_stack" {
  name             = var.release_name
  chart            = var.chart_path
  namespace        = var.namespace
  create_namespace = true
  timeout          = 600
  wait             = true

  # All values files
  values = [
    file("${var.chart_path}/values/global/global.yaml"),
    file("${var.chart_path}/values/vault/vault.yaml"),
    file("${var.chart_path}/values/elasticsearch/elasticsearch.yaml"),
    file("${var.chart_path}/values/grafana/grafana.yaml"),
    file("${var.chart_path}/values/prometheus/prometheus.yaml"),
    file("${var.chart_path}/values/loki/loki.yaml"),
    file("${var.chart_path}/values/promtail/promtail.yaml"),
  ]

  # Override with license secret
  set {
    name  = "secrets.vault.license"
    value = var.vault_license_b64
  }
}

# ECK operator is deployed via the vault-stack chart
# Deploy Elasticsearch and Kibana using kubectl apply with retry logic

# Deploy ELK stack using kubectl with built-in retry
resource "null_resource" "elk_stack" {
  triggers = {
    elasticsearch_config = md5(jsonencode({
      version = "8.12.0"
      memory  = "512Mi-1Gi"
      cpu     = "500m-1000m"
    }))
    kibana_config = md5(jsonencode({
      version = "8.12.0"
      memory  = "512Mi-1Gi"
      cpu     = "500m-1000m"
    }))
  }

  provisioner "local-exec" {
    command = "${path.module}/../../scripts/deploy_elk.sh"
    environment = {
      NAMESPACE = var.namespace
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "NAMESPACE=vault-stack ${path.module}/../../scripts/destroy_elk.sh"
  }

  depends_on = [
    helm_release.vault_stack
  ]
}
