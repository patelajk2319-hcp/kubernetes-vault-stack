#!/bin/bash

# Clean/destroy the entire stack

# Source centralized color configuration
source "$(dirname "$0")/../lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"
RELEASE_NAME="${RELEASE_NAME:-vault-stack}"

# Stop port-forwards
pkill -f "port-forward.*${NAMESPACE}" || true

echo -e "${YELLOW}Destroying entire ${NAMESPACE} namespace...${NC}"

# Uninstall Helm release
helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || true

# Delete cluster-wide resources
kubectl delete clusterrole promtail 2>/dev/null || true
kubectl delete clusterrolebinding promtail 2>/dev/null || true

# Delete namespace
kubectl delete namespace "$NAMESPACE" --timeout=60s || true

# Remove local files
rm -f vault-init.json

echo -e "${GREEN}Stack destroyed${NC}"
