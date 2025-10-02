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

# Check if namespace is terminating and wait for it to be fully deleted
if kubectl get namespace "$NAMESPACE" 2>/dev/null | grep -q Terminating; then
  echo -e "${YELLOW}Namespace $NAMESPACE is terminating. Waiting for cleanup to complete...${NC}"
  kubectl get namespace "$NAMESPACE" -o json | \
    jq '.spec.finalizers = []' | \
    kubectl replace --raw "/api/v1/namespaces/$NAMESPACE/finalize" -f - || true

  # Wait for namespace to be fully deleted
  while kubectl get namespace "$NAMESPACE" &>/dev/null; do
    echo -e "${YELLOW}Waiting for namespace to be deleted...${NC}"
    sleep 2
  done
  echo -e "${GREEN}Namespace deleted${NC}"
fi

# Create namespace if it doesn't exist
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  echo -e "${BLUE}Creating namespace $NAMESPACE${NC}"
  kubectl create namespace "$NAMESPACE"
else
  echo -e "${GREEN}Namespace $NAMESPACE already exists${NC}"
fi

# Check if release exists and upgrade or install
# Note: Using separate values files for each service
if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "$RELEASE_NAME"; then
  echo -e "${YELLOW}Upgrading existing release${NC}"
  helm upgrade "$RELEASE_NAME" "$CHART_PATH" \
    -n "$NAMESPACE" \
    -f "$CHART_PATH/values/global/global.yaml" \
    -f "$CHART_PATH/values/vault/vault.yaml" \
    -f "$CHART_PATH/values/elasticsearch/elasticsearch.yaml" \
    -f "$CHART_PATH/values/grafana/grafana.yaml" \
    -f "$CHART_PATH/values/prometheus/prometheus.yaml" \
    -f "$CHART_PATH/values/loki/loki.yaml" \
    -f "$CHART_PATH/values/promtail/promtail.yaml"
else
  echo -e "${BLUE}Installing new release${NC}"
  helm install "$RELEASE_NAME" "$CHART_PATH" \
    -n "$NAMESPACE" \
    -f "$CHART_PATH/values/global/global.yaml" \
    -f "$CHART_PATH/values/vault/vault.yaml" \
    -f "$CHART_PATH/values/elasticsearch/elasticsearch.yaml" \
    -f "$CHART_PATH/values/grafana/grafana.yaml" \
    -f "$CHART_PATH/values/prometheus/prometheus.yaml" \
    -f "$CHART_PATH/values/loki/loki.yaml" \
    -f "$CHART_PATH/values/promtail/promtail.yaml"
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
# Auto-detect Vault pod name
VAULT_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$VAULT_POD" ]; then
  kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- vault status || echo -e "${YELLOW}Vault not ready yet${NC}"
else
  echo -e "${YELLOW}Vault pod not found${NC}"
fi
