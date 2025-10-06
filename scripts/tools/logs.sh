#!/bin/bash

# View logs for a service

# Source centralised colour configuration
source "$(dirname "$0")/../lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"
POD_NAME=$1

if [ -z "$POD_NAME" ]; then
  echo -e "${YELLOW}Usage: task logs -- <service-name>${NC}"
  echo ""
  echo -e "${BLUE}Available services:${NC}"
  kubectl get pods -n "$NAMESPACE" --no-headers -o custom-columns=":metadata.labels.app" | sort -u
  exit 1
fi

echo -e "${BLUE}Viewing logs for: ${GREEN}$POD_NAME${NC}"
kubectl logs -n "$NAMESPACE" -l app="$POD_NAME" --tail=100 -f
