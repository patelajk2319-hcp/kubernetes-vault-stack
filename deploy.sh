#!/bin/bash
set -e

NAMESPACE="vault-stack"

echo "🚀 Deploying Vault Stack to Kubernetes"
echo "========================================"
echo ""

# Step 1: Create namespace
echo "📦 Creating namespace: ${NAMESPACE}"
kubectl apply -f manifests/base/namespace.yaml
echo ""

# Step 2: Create PVCs
echo "💾 Creating Persistent Volume Claims..."
kubectl apply -f manifests/base/persistent-volumes.yaml
echo ""

# Step 3: Create secrets
echo "🔐 Creating secrets..."
echo "⚠️  WARNING: Update manifests/base/secrets.yaml with your actual Vault license before deploying!"
echo "Press Enter to continue or Ctrl+C to cancel..."
read
kubectl apply -f manifests/base/secrets.yaml
echo ""

# Step 4: Generate certificates
echo "🔒 Generating TLS certificates..."
./scripts/00_create-certs.sh
echo ""

# Step 5: Create Kubernetes secrets from certificates
echo "📝 Creating Kubernetes secrets from certificates..."
./scripts/create-k8s-secrets.sh
echo ""

# Step 6: Create ConfigMaps
echo "⚙️  Creating ConfigMaps..."
kubectl apply -f manifests/vault/configmap.yaml
kubectl apply -f manifests/redis/configmap.yaml
kubectl apply -f manifests/prometheus/configmap.yaml
kubectl apply -f manifests/loki/configmap.yaml
kubectl apply -f manifests/promtail/configmap.yaml
kubectl apply -f manifests/grafana/configmap.yaml
echo ""

# Step 7: Deploy Vault
echo "🏦 Deploying Vault..."
kubectl apply -f manifests/vault/statefulset.yaml
kubectl apply -f manifests/vault/service.yaml
echo "Waiting for Vault to be ready..."
kubectl wait --for=condition=ready pod -l app=vault -n ${NAMESPACE} --timeout=120s
echo ""

# Step 8: Deploy Redis
echo "🔴 Deploying Redis..."
kubectl apply -f manifests/redis/deployment.yaml
kubectl apply -f manifests/redis/service.yaml
echo ""

# Step 9: Deploy Elasticsearch
echo "🔍 Deploying Elasticsearch..."
kubectl apply -f manifests/elasticsearch/statefulset.yaml
kubectl apply -f manifests/elasticsearch/service.yaml
echo "Waiting for Elasticsearch to be ready (this may take a few minutes)..."
kubectl wait --for=condition=ready pod -l app=elasticsearch -n ${NAMESPACE} --timeout=300s
echo ""

# Step 10: Deploy Kibana
echo "📊 Deploying Kibana..."
kubectl apply -f manifests/kibana/deployment.yaml
kubectl apply -f manifests/kibana/service.yaml
echo ""

# Step 11: Deploy Prometheus
echo "📈 Deploying Prometheus..."
kubectl apply -f manifests/prometheus/deployment.yaml
kubectl apply -f manifests/prometheus/service.yaml
echo ""

# Step 12: Deploy Loki
echo "📝 Deploying Loki..."
kubectl apply -f manifests/loki/deployment.yaml
kubectl apply -f manifests/loki/service.yaml
echo ""

# Step 13: Deploy Promtail
echo "📋 Deploying Promtail..."
kubectl apply -f manifests/promtail/daemonset.yaml
echo ""

# Step 14: Deploy Grafana
echo "📊 Deploying Grafana..."
kubectl apply -f manifests/grafana/deployment.yaml
kubectl apply -f manifests/grafana/service.yaml
echo ""

echo "✅ Deployment complete!"
echo ""
echo "📌 Next steps:"
echo "1. Initialize Vault: kubectl apply -f manifests/vault/init-job.yaml"
echo "2. Retrieve Vault init data from the job logs"
echo "3. Access services:"
echo "   - Vault:      http://<node-ip>:30820"
echo "   - Grafana:    http://<node-ip>:30300"
echo "   - Prometheus: http://<node-ip>:30909"
echo "   - Kibana:     https://<node-ip>:30561"
echo ""
echo "To get your node IP: kubectl get nodes -o wide"