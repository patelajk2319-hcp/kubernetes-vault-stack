#!/bin/bash

# Unseal Vault using the unseal key from vault-init.json
# This script checks if Vault has been initialized and unseals it

set -e

# Source centralized color configuration
source "$(dirname "$0")/lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"
VAULT_POD="${VAULT_POD:-vault-0}"

# Check if Vault is initialized
if [ ! -f vault-init.json ]; then
  echo -e "${YELLOW}vault-init.json not found${NC}"
  echo "Run 'task init' first to initialize Vault"
  exit 1
fi

echo -e "${BLUE}Vault initialization file found${NC}"

# Unseal Vault
UNSEAL_KEY=$(cat vault-init.json | jq -r '.unseal_keys_b64[0]')
echo -e "${BLUE}Unsealing Vault${NC}"
kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- \
  vault operator unseal "$UNSEAL_KEY"

echo -e "${GREEN}Vault unsealed!${NC}"
