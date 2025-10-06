#!/bin/bash

# Clean/destroy the entire stack using Terraform

# Source centralized color configuration
source "$(dirname "$0")/../lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"

# Stop port-forwards
echo -e "${BLUE}Stopping port-forwards...${NC}"
pkill -f "port-forward.*${NAMESPACE}" 2>/dev/null || true

# Run Terraform destroy
echo -e "${YELLOW}Running Terraform Destroy...${NC}"
cd "$(dirname "$0")/../../terraform"

# Check if .terraform directory exists (indicates modules are installed)
if [ ! -d ".terraform" ]; then
  echo -e "${YELLOW}No Terraform modules installed - nothing to destroy${NC}"
  cd ..

  # Remove vault-init.json if it exists
  if [ -f vault-init.json ]; then
    rm -f vault-init.json
    echo -e "${GREEN}Removed vault-init.json${NC}"
  fi

  echo -e "${GREEN}Stack already destroyed${NC}"
  exit 0
fi

# Run destroy (don't use set -e to allow cleanup even if destroy fails)
if terraform destroy -auto-approve; then
  # Clean up Terraform state files only if destroy succeeded
  echo -e "${BLUE}Cleaning up Terraform state files...${NC}"
  rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
  rm -rf .terraform/
  echo -e "${GREEN}Terraform state files removed${NC}"
else
  echo -e "${YELLOW}Terraform destroy failed!${NC}"
  exit 1
fi

# Remove vault-init.json if it exists
cd ..
if [ -f vault-init.json ]; then
  rm -f vault-init.json
  echo -e "${GREEN}Removed vault-init.json${NC}"
fi

echo -e "${GREEN}Stack destroyed${NC}"
