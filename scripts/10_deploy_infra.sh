#!/bin/bash

# Deploy the entire Vault stack using Terraform

set -e

# Source centralised colour configuration
source "$(dirname "$0")/lib/colors.sh"

echo -e "${BLUE}=== Deploying Vault Stack Infrastructure ===${NC}"

# Change to terraform directory
cd "$(dirname "$0")/../terraform"

# Initialise Terraform
echo -e "${BLUE}Initialising Terraform...${NC}"
terraform init -upgrade

# Apply Terraform configuration
echo -e "${BLUE}Applying Terraform configuration...${NC}"
terraform apply -auto-approve

echo ""
echo -e "${GREEN}=== Infrastructure Deployed Successfully! ===${NC}"
echo ""

