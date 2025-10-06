#!/bin/bash

# Unseal Vault using the unseal key from vault-init.json
# This script checks if Vault has been initialised and unseals it

set -e

# Source centralized color configuration
source "$(dirname "$0")/lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"
VAULT_POD="${VAULT_POD:-vault-0}"

# Auto-detect Vault pod name if default doesn't exist
if ! kubectl get pod -n "$NAMESPACE" "$VAULT_POD" &>/dev/null; then
  echo -e "${YELLOW}Pod $VAULT_POD not found, auto-detecting Vault pod...${NC}"
  VAULT_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -z "$VAULT_POD" ]; then
    echo -e "${RED}Error: No Vault pod found in namespace $NAMESPACE${NC}"
    exit 1
  fi
  echo -e "${GREEN}Found Vault pod: $VAULT_POD${NC}"
fi

# Check if Vault is initialised
if [ ! -f vault-init.json ]; then
  echo -e "${YELLOW}vault-init.json not found${NC}"
  echo "Run 'task init' first to initialise Vault"
  exit 1
fi

echo -e "${BLUE}Vault initialisation file found${NC}"

# Unseal Vault
UNSEAL_KEY=$(cat vault-init.json | jq -r '.unseal_keys_b64[0]')
echo -e "${BLUE}Unsealing Vault${NC}"
kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- \
  vault operator unseal "$UNSEAL_KEY"

echo -e "${GREEN}Vault unsealed!${NC}"
