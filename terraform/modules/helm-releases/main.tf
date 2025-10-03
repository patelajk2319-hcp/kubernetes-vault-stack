# HashiCorp Vault Enterprise
resource "helm_release" "vault" {
  name             = "vault-stack"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  version          = "0.31.0"
  namespace        = var.namespace
  create_namespace = true
  timeout          = 600
  wait             = true

  values = [
    file("${path.root}/../helm-chart/vault-stack/values/vault/vault.yaml")
  ]
}

# Elastic Cloud on Kubernetes (ECK) Operator
resource "helm_release" "eck_operator" {
  name       = "elastic-operator"
  repository = "https://helm.elastic.co"
  chart      = "eck-operator"
  version    = "2.10.0"
  namespace  = var.namespace
  timeout    = 300
  wait       = true

  values = [
    file("${path.root}/../helm-chart/vault-stack/values/elasticsearch/elasticsearch.yaml")
  ]

  depends_on = [
    helm_release.vault
  ]
}

# Grafana
resource "helm_release" "grafana" {
  name       = "vault-stack-grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "8.9.0"
  namespace  = var.namespace
  timeout    = 300
  wait       = true

  values = [
    file("${path.root}/../helm-chart/vault-stack/values/grafana/grafana.yaml")
  ]

  depends_on = [
    helm_release.vault
  ]
}

# Prometheus
resource "helm_release" "prometheus" {
  name       = "vault-stack-prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = "25.28.0"
  namespace  = var.namespace
  timeout    = 300
  wait       = true

  values = [
    file("${path.root}/../helm-chart/vault-stack/values/prometheus/prometheus.yaml")
  ]

  depends_on = [
    helm_release.vault
  ]
}

# Loki
resource "helm_release" "loki" {
  name       = "vault-stack-loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "6.27.0"
  namespace  = var.namespace
  timeout    = 300
  wait       = true

  values = [
    file("${path.root}/../helm-chart/vault-stack/values/loki/loki.yaml")
  ]

  depends_on = [
    helm_release.vault
  ]
}

# Promtail
resource "helm_release" "promtail" {
  name       = "vault-stack-promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = "6.16.6"
  namespace  = var.namespace
  timeout    = 300
  wait       = true

  values = [
    file("${path.root}/../helm-chart/vault-stack/values/promtail/promtail.yaml")
  ]

  depends_on = [
    helm_release.loki
  ]
}

# Deploy ELK stack using kubectl with built-in retry
# ECK operator must be deployed and CRDs ready before deploying Elasticsearch/Kibana
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
    command     = "bash -c 'cd ${path.root} && ./scripts/deploy_elk.sh'"
    environment = {
      NAMESPACE = var.namespace
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "bash -c 'cd ${path.root} && NAMESPACE=vault-stack ./scripts/destroy_elk.sh'"
  }

  depends_on = [
    helm_release.eck_operator
  ]
}
