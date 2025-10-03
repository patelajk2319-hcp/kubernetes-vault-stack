#!/bin/bash

set -e

# Source centralized color configuration
source "$(dirname "$0")/lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"

# Stop any existing port-forwards
pkill -f "port-forward.*${NAMESPACE}" 2>/dev/null || true

echo -e "${BLUE}Setting up port-forwards in background${NC}"

# Vault - using NodePort service created by Terraform
nohup kubectl port-forward -n "$NAMESPACE" svc/vault-nodeport 8200:8200 > /dev/null 2>&1 &

# Elasticsearch - ECK creates elasticsearch-es-http service
nohup kubectl port-forward -n "$NAMESPACE" svc/elasticsearch-es-http 9200:9200 > /dev/null 2>&1 &

# Kibana - ECK creates kibana-kb-http service
# Wait for Kibana pod to be ready before port-forwarding
kubectl wait --for=condition=ready pod -l kibana.k8s.elastic.co/name=kibana -n "$NAMESPACE" --timeout=120s 2>/dev/null || true
nohup kubectl port-forward -n "$NAMESPACE" svc/kibana-kb-http 5601:5601 > /dev/null 2>&1 &

# Grafana - official chart uses release name prefix
nohup kubectl port-forward -n "$NAMESPACE" svc/vault-stack-grafana 3000:80 > /dev/null 2>&1 &

# Prometheus - official chart uses release name prefix
nohup kubectl port-forward -n "$NAMESPACE" svc/vault-stack-prometheus-server 9090:80 > /dev/null 2>&1 &

sleep 2
echo -e "${GREEN}Port-forwards active...${NC}"
