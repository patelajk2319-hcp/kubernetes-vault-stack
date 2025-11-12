#!/bin/bash
set -euo pipefail

# Show status of all components

# Source centralised colour configuration
source "$(dirname "$0")/../lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"
VAULT_POD="${VAULT_POD:-vault-stack-0}"

echo -e "${BLUE}=== Pods ===${NC}"
kubectl get pods -n "$NAMESPACE"

echo ""
echo -e "${BLUE}=== Services ===${NC}"
kubectl get svc -n "$NAMESPACE"

echo ""
echo -e "${BLUE}=== Vault Status ===${NC}"
kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- vault status || echo -e "${YELLOW}Vault not ready yet${NC}"

echo ""
echo -e "${BLUE}=== ELK Stack (Podman Containers) ===${NC}"
if command -v podman >/dev/null 2>&1; then
  if podman ps --filter "name=^k8s_vault_" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -q "k8s_vault_"; then
    podman ps --filter "name=^k8s_vault_" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  else
    echo -e "${YELLOW}No ELK stack containers found${NC}"
    echo -e "${YELLOW}Run 'task up' to deploy the full stack${NC}"
  fi
else
  echo -e "${RED}Podman not installed${NC}"
fi
