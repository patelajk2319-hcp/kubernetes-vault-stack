#!/bin/bash

# Deploy Elasticsearch and Kibana via ECK operator
# This script waits for ECK CRDs to be available and then deploys the resources

set -e

NAMESPACE="${NAMESPACE:-vault-stack}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"

echo "Waiting for ECK operator CRDs to be ready..."

# Wait for ECK operator pod to be running
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=elastic-operator -n "$NAMESPACE" --timeout=120s || true

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
echo "Deploying Elasticsearch..."
sed "s/NAMESPACE_PLACEHOLDER/$NAMESPACE/g" "$CONFIG_DIR/elasticsearch.yaml" | kubectl apply -f -

# Wait a bit for Elasticsearch to start creating
sleep 10

# Deploy Kibana
echo "Deploying Kibana..."
sed "s/NAMESPACE_PLACEHOLDER/$NAMESPACE/g" "$CONFIG_DIR/kibana.yaml" | kubectl apply -f -

echo "ELK stack deployed successfully"
