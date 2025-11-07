#!/bin/bash

# Deploy Elasticsearch dynamic credentials demo using Terraform

set -euo pipefail

# Source centralised colour configuration
source "$(dirname "$0")/../lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"

echo -e "${BLUE}=== Deploying Elasticsearch Dynamic Credentials ===${NC}"
echo ""

# Change to tf-dynamic-elk directory
cd "$(dirname "$0")/../../terraform/tf-dynamic-elk"

# Check if .env exists
if [ ! -f "../../.env" ]; then
  echo -e "${RED}Error: .env file not found${NC}"
  echo -e "${YELLOW}Run 'task init' and 'task unseal' first${NC}"
  exit 1
fi

# Source environment variables (VAULT_ADDR, VAULT_TOKEN)
echo -e "${BLUE}Loading Vault environment variables...${NC}"
source ../../.env

# Verify VAULT_TOKEN is set
if [ -z "$VAULT_TOKEN" ]; then
  echo -e "${RED}Error: VAULT_TOKEN not set in .env${NC}"
  echo -e "${YELLOW}Run 'task init' first${NC}"
  exit 1
fi

# Check if Elasticsearch is running (Podman)
echo -e "${BLUE}Checking Elasticsearch availability (Podman)...${NC}"
if ! podman ps --format "{{.Names}}" 2>/dev/null | grep -q "^k8s_vault_elasticsearch$"; then
  echo -e "${RED}Error: Elasticsearch not found in Podman${NC}"
  echo -e "${YELLOW}Ensure Elasticsearch is running via 'task up' (elk-compose.yml)${NC}"
  exit 1
fi

# Test Elasticsearch connectivity from host
if ! curl -k -s -u elastic:password123 https://localhost:9200/_cluster/health > /dev/null 2>&1; then
  echo -e "${YELLOW}Warning: Cannot connect to Elasticsearch at https://localhost:9200${NC}"
  echo -e "${YELLOW}Dynamic credentials may not work properly${NC}"
fi

# Check if VSO is configured (vault-connection should exist)
echo -e "${BLUE}Checking VSO prerequisites...${NC}"
if ! kubectl get vaultconnection vault-connection -n "${NAMESPACE}" > /dev/null 2>&1; then
  echo -e "${YELLOW}Warning: VaultConnection not found. Running 'task vso' first...${NC}"
  cd ..
  NAMESPACE="${NAMESPACE}" ./scripts/vso/00_deploy_vso.sh
  cd terraform/tf-dynamic-elk
fi

# Create custom Elasticsearch role (required for dynamic credentials)
echo -e "${BLUE}Creating custom Elasticsearch role...${NC}"
ROLE_CREATE_OUTPUT=$(curl -k -s -u elastic:password123 -X POST "https://localhost:9200/_security/role/vault_es_role" \
  -H 'Content-Type: application/json' -d'
{
  "cluster": [
    "monitor",
    "manage_index_templates",
    "monitor_ml",
    "monitor_watcher",
    "monitor_transform"
  ],
  "indices": [
    {
      "names": [ "*" ],
      "privileges": [
        "read",
        "write",
        "create_index",
        "delete_index",
        "view_index_metadata",
        "monitor"
      ],
      "allow_restricted_indices": true
    }
  ],
  "applications": [
    {
      "application": "kibana-.kibana",
      "privileges": [ "all" ],
      "resources": [ "*" ]
    }
  ],
  "run_as": []
}' 2>&1)

if echo "$ROLE_CREATE_OUTPUT" | grep -q '"created":true'; then
  echo -e "${GREEN}✓ Custom role 'vault_es_role' created${NC}"
elif echo "$ROLE_CREATE_OUTPUT" | grep -q 'already exists'; then
  echo -e "${YELLOW}⚠ Custom role 'vault_es_role' already exists (skipping)${NC}"
else
  echo -e "${GREEN}✓ Custom role 'vault_es_role' configured${NC}"
fi

# Initialise Terraform
echo -e "${BLUE}Initialising Terraform...${NC}"
terraform init -upgrade

# Apply Terraform configuration
echo -e "${BLUE}Applying Terraform configuration...${NC}"
terraform apply -auto-approve

echo ""
echo -e "${BLUE}Waiting for dynamic credentials to be generated...${NC}"
sleep 20

echo ""
echo -e "${GREEN}=== Elasticsearch Dynamic Credentials Deployed Successfully! ===${NC}"
echo ""
echo -e "${YELLOW}Status:${NC}"
kubectl get vaultdynamicsecret -n "${NAMESPACE}" 2>/dev/null || echo "No VaultDynamicSecret resources found yet"
echo ""
echo -e "${YELLOW}Secrets:${NC}"
kubectl get secret elasticsearch-dynamic-secret -n "${NAMESPACE}" 2>/dev/null && echo "✅ Dynamic secret created" || echo "⏳ Waiting for secret creation"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  - ${BLUE}task info${NC}  - View credentials and access information"
echo ""
