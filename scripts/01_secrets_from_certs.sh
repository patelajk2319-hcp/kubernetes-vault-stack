#!/bin/bash

# Create Kubernetes secrets from certificate files
# This script creates secrets for Elasticsearch and Kibana TLS certificates

set -e

# Source centralized color configuration
source "$(dirname "$0")/lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"

# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" 2>/dev/null || true

# Generate certificates if not already present
if [ ! -d certs ]; then
  echo "No certs directory found"
  echo "Running certificate generation script..."
  ./scripts/00_create-certs.sh
fi

echo -e "${BLUE}Creating certificate secrets${NC}"

# Create Elasticsearch certificate secret
kubectl create secret generic elasticsearch-certs \
  --from-file=ca.crt=certs/ca/ca.crt \
  --from-file=elasticsearch.crt=certs/elasticsearch/elasticsearch.crt \
  --from-file=elasticsearch.key=certs/elasticsearch/elasticsearch.key \
  --from-file=fleet-server.crt=certs/fleet-server/fleet-server.crt \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Create Kibana certificate secret
kubectl create secret generic kibana-certs \
  --from-file=ca.crt=certs/ca/ca.crt \
  --from-file=kibana.crt=certs/kibana/kibana.crt \
  --from-file=kibana.key=certs/kibana/kibana.key \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo -e "${GREEN}Certificate secrets created${NC}"
