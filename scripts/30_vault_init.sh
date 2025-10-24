#!/bin/bash

# Initialise Vault and save credentials
# This script checks if Vault is already initialised, initialises it with a single key,
# and saves the root token to .env and all credentials to vault-init.json

set -e

# Source centralised colour configuration
source "$(dirname "$0")/lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"
VAULT_POD="${VAULT_POD:-vault-stack-0}"

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

# Check if Vault is already initialised
STATUS=$(kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- vault status -format=json 2>&1 || echo '{"initialized":false}')
INITIALIZED=$(echo "$STATUS" | grep -o '"initialized":[^,]*' | cut -d':' -f2)

if [ "$INITIALIZED" = "true" ]; then
  echo -e "${YELLOW}Vault is already initialised${NC}"
  echo "Vault details are in vault-init.json and .env"
  echo "If you want to re-initialise, run 'task clean' first"
  exit 1
fi

# Initialise Vault with single key
echo -e "${BLUE}Initialising Vault${NC}"
kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- \
  vault operator init \
  -key-shares=1 \
  -key-threshold=1 \
  -format=json > vault-init.json

echo -e "${GREEN}Vault Token and Key${NC}"
cat vault-init.json | jq -r '"Root Token: " + .root_token'
cat vault-init.json | jq -r '"Unseal Key: " + .unseal_keys_b64[0]'

# Save root token to .env (unseal key is only in vault-init.json)
ROOT_TOKEN=$(cat vault-init.json | jq -r '.root_token')

# Update VAULT_TOKEN in .env
sed -i.bak "s|^export VAULT_TOKEN=.*|export VAULT_TOKEN=$ROOT_TOKEN|" .env
rm -f .env.bak

# Unseal Vault
echo -e "${BLUE}Unsealing Vault${NC}"
UNSEAL_KEY=$(cat vault-init.json | jq -r '.unseal_keys_b64[0]')
kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- vault operator unseal "$UNSEAL_KEY" >/dev/null

echo -e "${GREEN}Vault initialised!${NC}"
echo -e "${GREEN}Vault token saved to .env${NC}"
echo
echo -e "${YELLOW}Note: Run 'task audit' to configure audit logging and ELK integration${NC}"
