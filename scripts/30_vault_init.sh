#!/bin/bash

# Initialize Vault and save credentials
# This script checks if Vault is already initialized, initializes it with a single key,
# and saves the root token to .env and all credentials to vault-init.json

set -e

# Source centralized color configuration
source "$(dirname "$0")/lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"
VAULT_POD="${VAULT_POD:-vault-0}"

# Check if Vault is already initialized
STATUS=$(kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- vault status -format=json 2>&1 || echo '{"initialized":false}')
INITIALIZED=$(echo "$STATUS" | grep -o '"initialized":[^,]*' | cut -d':' -f2)

if [ "$INITIALIZED" = "true" ]; then
  echo -e "${YELLOW}Vault is already initialized${NC}"
  echo "Vault details are in vault-init.json and .env"
  echo "If you want to re-initialize, run 'task clean' first"
  exit 1
fi

# Initialize Vault with single key
echo -e "${BLUE}Initializing Vault${NC}"
kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- \
  vault operator init \
  -key-shares=1 \
  -key-threshold=1 \
  -format=json > vault-init.json

echo -e "${GREEN}Vault initialized${NC}"
cat vault-init.json | jq -r '"Root Token: " + .root_token'
cat vault-init.json | jq -r '"Unseal Key: " + .unseal_keys_b64[0]'

# Save root token to .env (unseal key is only in vault-init.json)
ROOT_TOKEN=$(cat vault-init.json | jq -r '.root_token')

# Update VAULT_TOKEN in .env
sed -i.bak "s|^export VAULT_TOKEN=.*|export VAULT_TOKEN=$ROOT_TOKEN|" .env
rm -f .env.bak

echo -e "${GREEN}Vault initialised!${NC}"
echo -e "${GREEN}Vault token saved to .env${NC}"
