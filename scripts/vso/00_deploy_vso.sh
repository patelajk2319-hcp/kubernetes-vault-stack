#!/bin/bash

# Deploy VSO demo using Terraform

set -e

# Source centralised colour configuration
source "$(dirname "$0")/../lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"

echo -e "${BLUE}=== Deploying VSO ===${NC}"
echo ""

# Change to tf-vso directory
cd "$(dirname "$0")/../../terraform/tf-vso"

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

# Initialise Terraform
echo -e "${BLUE}Initialising Terraform...${NC}"
terraform init -upgrade

# Apply Terraform configuration
echo -e "${BLUE}Applying VSO Terraform configuration...${NC}"
terraform apply -auto-approve

echo ""
echo -e "${BLUE}Waiting for VSO to sync secrets...${NC}"
sleep 15

echo ""
echo -e "${GREEN}=== VSO Deployed Successfully! ===${NC}"
echo ""
echo -e "${YELLOW}Status:${NC}"
kubectl get vaultstaticsecret -n "${NAMESPACE}"
echo ""
kubectl get pods -l app=webapp -n "${NAMESPACE}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  - ${BLUE}task vso-webapp${NC}  - Access demo webapp"
echo -e "  - ${BLUE}task vso-update${NC}  - Test secret synchronisation"
echo ""
