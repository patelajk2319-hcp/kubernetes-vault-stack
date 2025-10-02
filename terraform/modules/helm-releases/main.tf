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
    command = <<-EOT
      set -e
      echo "Waiting for ECK operator CRDs to be ready..."

      # Wait for ECK operator pod to be running
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=elastic-operator -n ${var.namespace} --timeout=120s || true

      # Retry loop for CRD availability (max 3 minutes)
      for i in {1..18}; do
        if kubectl get crd elasticsearches.elasticsearch.k8s.elastic.co >/dev/null 2>&1; then
          echo "ECK CRDs are ready"
          break
        fi
        echo "Waiting for ECK CRDs... (attempt $i/18)"
        sleep 10
      done

      # Deploy Elasticsearch
      cat <<EOF | kubectl apply -f -
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: elasticsearch
  namespace: ${var.namespace}
spec:
  version: 8.12.0
  nodeSets:
  - name: default
    count: 1
    config:
      node.store.allow_mmap: false
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 20Gi
    podTemplate:
      spec:
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 512Mi
              cpu: 500m
            limits:
              memory: 1Gi
              cpu: 1000m
EOF

      # Wait a bit for Elasticsearch to start creating
      sleep 10

      # Deploy Kibana
      cat <<EOF | kubectl apply -f -
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: kibana
  namespace: ${var.namespace}
spec:
  version: 8.12.0
  count: 1
  elasticsearchRef:
    name: elasticsearch
  podTemplate:
    spec:
      containers:
      - name: kibana
        resources:
          requests:
            memory: 512Mi
            cpu: 500m
          limits:
            memory: 1Gi
            cpu: 1000m
EOF

      echo "ELK stack deployed successfully"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      kubectl delete kibana kibana -n vault-stack --ignore-not-found=true
      kubectl delete elasticsearch elasticsearch -n vault-stack --ignore-not-found=true
    EOT
  }

  depends_on = [
    helm_release.vault_stack
  ]
}
