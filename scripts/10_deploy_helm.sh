#!/bin/bash

set -e

# Source centralized color configuration
source "$(dirname "$0")/lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"
RELEASE_NAME="${RELEASE_NAME:-vault-stack}"
CHART_PATH="${CHART_PATH:-./helm-chart/vault-stack}"

echo -e "${BLUE}Deploying Helm chart${NC}"

# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" 2>/dev/null || true

# Check if release exists and upgrade or install
if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "$RELEASE_NAME"; then
  echo -e "${YELLOW}Upgrading existing release${NC}"
  helm upgrade "$RELEASE_NAME" "$CHART_PATH" -n "$NAMESPACE"
else
  echo -e "${BLUE}Installing new release${NC}"
  helm install "$RELEASE_NAME" "$CHART_PATH" -n "$NAMESPACE"
fi

echo ""
echo -e "${BLUE}Waiting for pods to be ready (this may take up to 10 minutes)${NC}"
kubectl wait --for=condition=ready pod --all -n "$NAMESPACE" --timeout=600s || true

echo ""
echo -e "${BLUE}Pods${NC}"
kubectl get pods -n "$NAMESPACE"
echo ""
echo -e "${BLUE}Services${NC}"
kubectl get svc -n "$NAMESPACE"
echo ""
echo -e "${BLUE}Vault Status${NC}"
kubectl exec -n "$NAMESPACE" vault-0 -- vault status || echo -e "${YELLOW}Vault not ready yet${NC}"
