# ==============================================================================
# Helm Releases for Vault Stack Components
# ==============================================================================
# This module deploys all components using official Helm charts from their
# respective official repositories. Each component is deployed as a separate
# helm_release resource for better modularity and independent lifecycle management.
#
# IMPORTANT: wait=false is used for all releases because Vault pods won't be
# ready until manually initialized and unsealed. The deployment workflow is:
# 1. terraform apply (deploys all charts)
# 2. task init (initialize Vault)
# 3. task unseal (unseal Vault and start port-forwarding)
# ==============================================================================

# HashiCorp Vault Enterprise - Secrets management platform
# Official chart from HashiCorp Helm repository
resource "helm_release" "vault" {
  name             = "vault-stack"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  version          = "0.31.0"
  namespace        = var.namespace
  create_namespace = true
  timeout          = 600
  wait             = false # Pods won't be ready until manual init/unseal

  values = [
    file("${path.root}/../helm-chart/vault-stack/values/vault/vault.yaml")
  ]
}

# ------------------------------------------------------------------------------
# Observability Stack Components
# ------------------------------------------------------------------------------

# ECK Operator - Manages Elasticsearch and Kibana via Custom Resources
# Official chart from Elastic Helm repository
# Note: Elasticsearch and Kibana are deployed via kubectl (see elk_stack below)
resource "helm_release" "eck_operator" {
  name       = "elastic-operator"
  repository = "https://helm.elastic.co"
  chart      = "eck-operator"
  version    = "2.10.0"
  namespace  = var.namespace
  timeout    = 300
  wait       = false

  values = [
    file("${path.root}/../helm-chart/vault-stack/values/elasticsearch/elasticsearch.yaml")
  ]

  depends_on = [
    helm_release.vault
  ]
}

# Grafana - Visualization and dashboards for metrics and logs
# Official chart from Grafana Helm repository
resource "helm_release" "grafana" {
  name       = "vault-stack-grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "8.9.0"
  namespace  = var.namespace
  timeout    = 300
  wait       = false

  values = [
    file("${path.root}/../helm-chart/vault-stack/values/grafana/grafana.yaml")
  ]

  depends_on = [
    helm_release.vault
  ]
}

# Prometheus - Metrics collection and storage
# Official chart from Prometheus Community Helm repository
resource "helm_release" "prometheus" {
  name       = "vault-stack-prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = "25.28.0"
  namespace  = var.namespace
  timeout    = 300
  wait       = false

  values = [
    file("${path.root}/../helm-chart/vault-stack/values/prometheus/prometheus.yaml")
  ]

  depends_on = [
    helm_release.vault
  ]
}

# Loki - Log aggregation system
# Official chart from Grafana Helm repository
resource "helm_release" "loki" {
  name       = "vault-stack-loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "6.27.0"
  namespace  = var.namespace
  timeout    = 300
  wait       = false

  values = [
    file("${path.root}/../helm-chart/vault-stack/values/loki/loki.yaml")
  ]

  depends_on = [
    helm_release.vault
  ]
}

# Promtail - Log collector that ships logs to Loki
# Official chart from Grafana Helm repository
resource "helm_release" "promtail" {
  name       = "vault-stack-promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = "6.16.6"
  namespace  = var.namespace
  timeout    = 300
  wait       = false

  values = [
    file("${path.root}/../helm-chart/vault-stack/values/promtail/promtail.yaml")
  ]

  depends_on = [
    helm_release.loki # Promtail depends on Loki being available
  ]
}

# ------------------------------------------------------------------------------
# ELK Stack Deployment via kubectl
# ------------------------------------------------------------------------------
# Elasticsearch and Kibana are deployed as ECK Custom Resources using kubectl
# rather than Helm because ECK operator manages them via CRDs. The deploy_elk.sh
# script contains the resource manifests and includes retry logic to wait for
# ECK operator CRDs to be ready before applying.
#
# This resource triggers redeployment when config changes are detected.
# ------------------------------------------------------------------------------
resource "null_resource" "elk_stack" {
  # Trigger redeployment when ELK configuration changes
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

  # Deploy Elasticsearch and Kibana via kubectl
  provisioner "local-exec" {
    command     = "bash -c 'cd ${path.root} && ./scripts/deploy_elk.sh'"
    environment = {
      NAMESPACE = var.namespace
    }
  }

  # Clean up ELK resources on destroy
  provisioner "local-exec" {
    when    = destroy
    command = "bash -c 'cd ${path.root} && NAMESPACE=vault-stack ./scripts/destroy_elk.sh'"
  }

  depends_on = [
    helm_release.eck_operator # Wait for ECK operator to be deployed
  ]
}
