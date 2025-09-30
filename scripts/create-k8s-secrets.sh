#!/bin/bash
set -e

# This script creates Kubernetes secrets from the generated certificates
# Run this after running 00_create-certs.sh

NAMESPACE="vault-stack"
CERT_DIR="./certs"

echo "Creating Kubernetes secrets from certificates..."

# Create secret for Elasticsearch certificates
kubectl create secret generic elasticsearch-certs \
  --from-file=ca.crt=${CERT_DIR}/ca/ca.crt \
  --from-file=ca.key=${CERT_DIR}/ca/ca.key \
  --from-file=elasticsearch.crt=${CERT_DIR}/elasticsearch/elasticsearch.crt \
  --from-file=elasticsearch.key=${CERT_DIR}/elasticsearch/elasticsearch.key \
  --namespace=${NAMESPACE} \
  --dry-run=client -o yaml | kubectl apply -f -

# Create secret for Kibana certificates
kubectl create secret generic kibana-certs \
  --from-file=ca.crt=${CERT_DIR}/ca/ca.crt \
  --from-file=kibana.crt=${CERT_DIR}/kibana/kibana.crt \
  --from-file=kibana.key=${CERT_DIR}/kibana/kibana.key \
  --namespace=${NAMESPACE} \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Kubernetes secrets created successfully!"
echo ""
echo "Secrets created:"
echo "  - elasticsearch-certs"
echo "  - kibana-certs"