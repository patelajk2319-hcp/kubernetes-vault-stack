# HashiCorp Vault Enterprise
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

# Grafana - Visualisation and dashboards for metrics and logs
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
