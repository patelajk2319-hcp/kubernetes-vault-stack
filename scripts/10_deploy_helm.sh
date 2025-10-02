#!/bin/bash

set -e

# Source centralized color configuration
source "$(dirname "$0")/lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"
RELEASE_NAME="${RELEASE_NAME:-vault-stack}"
CHART_PATH="${CHART_PATH:-./helm-chart/vault-stack}"

echo -e "${BLUE}Deploying Helm chart${NC}"

# Add required Helm repositories
echo -e "${BLUE}Adding Helm repositories${NC}"
helm repo add hashicorp https://helm.releases.hashicorp.com 2>/dev/null || true
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo add elastic https://helm.elastic.co 2>/dev/null || true
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

# Build chart dependencies
echo -e "${BLUE}Building chart dependencies (downloading official charts)${NC}"
helm dependency update "$CHART_PATH"

# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" 2>/dev/null || true

# Check if release exists and upgrade or install
# Note: Using the main values.yaml file which configures all dependencies
if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "$RELEASE_NAME"; then
  echo -e "${YELLOW}Upgrading existing release${NC}"
  helm upgrade "$RELEASE_NAME" "$CHART_PATH" \
    -n "$NAMESPACE" \
    -f "$CHART_PATH/values.yaml"
else
  echo -e "${BLUE}Installing new release${NC}"
  helm install "$RELEASE_NAME" "$CHART_PATH" \
    -n "$NAMESPACE" \
    -f "$CHART_PATH/values.yaml"
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
