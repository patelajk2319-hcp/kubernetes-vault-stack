#!/bin/bash

# Clean/destroy the entire stack using Terraform

set -e

# Source centralized color configuration
source "$(dirname "$0")/../lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"

# Stop port-forwards
echo -e "${BLUE}Stopping port-forwards...${NC}"
pkill -f "port-forward.*${NAMESPACE}" 2>/dev/null || true

# Run Terraform destroy
echo -e "${YELLOW}Running Terraform Destroy...${NC}"
cd "$(dirname "$0")/../../terraform"
terraform destroy -auto-approve

# Remove vault-init.json if it exists
cd ..
if [ -f vault-init.json ]; then
  rm -f vault-init.json
  echo -e "${GREEN}Removed vault-init.json${NC}"
fi

echo -e "${GREEN}Stack destroyed${NC}"
