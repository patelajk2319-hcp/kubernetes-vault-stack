#!/bin/bash

set -e

# Source centralized color configuration
source "$(dirname "$0")/lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"

# Stop any existing port-forwards
pkill -f "port-forward.*${NAMESPACE}" 2>/dev/null || true

echo -e "${BLUE}Setting up port-forwards in background${NC}"

nohup kubectl port-forward -n "$NAMESPACE" svc/vault 8200:8200 > /dev/null 2>&1 &
nohup kubectl port-forward -n "$NAMESPACE" svc/elasticsearch 9200:9200 > /dev/null 2>&1 &
nohup kubectl port-forward -n "$NAMESPACE" svc/kibana 5601:5601 > /dev/null 2>&1 &
nohup kubectl port-forward -n "$NAMESPACE" svc/grafana 3000:3000 > /dev/null 2>&1 &
nohup kubectl port-forward -n "$NAMESPACE" svc/prometheus 9090:9090 > /dev/null 2>&1 &
nohup kubectl port-forward -n "$NAMESPACE" svc/redis 6379:6379 > /dev/null 2>&1 &

sleep 2
echo -e "${GREEN}Port-forwards active in background${NC}"
