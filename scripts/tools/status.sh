#!/bin/bash

# Show status of all components

# Source centralized color configuration
source "$(dirname "$0")/../lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"
VAULT_POD="${VAULT_POD:-vault-0}"

echo -e "${BLUE}=== Pods ===${NC}"
kubectl get pods -n "$NAMESPACE"

echo ""
echo -e "${BLUE}=== Services ===${NC}"
kubectl get svc -n "$NAMESPACE"

echo ""
echo -e "${BLUE}=== Vault Status ===${NC}"
kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- vault status || echo -e "${YELLOW}Vault not ready yet${NC}"
