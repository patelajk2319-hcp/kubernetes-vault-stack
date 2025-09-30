#!/usr/bin/env bash
set -e

export VAULT_ADDR=http://vault:8200

if [ ! -f /vault-init/vault-init.json ]; then
  echo "❌ Error: vault-init.json not found!"
  echo "Please run vault-init.sh first to initialize Vault."
  exit 1
fi

echo "Checking Vault status..."
vault status || true

echo "Unsealing Vault..."
vault operator unseal $(cat /vault-init/vault-init.json | jq -r '.unseal_keys_b64[0]')
vault operator unseal $(cat /vault-init/vault-init.json | jq -r '.unseal_keys_b64[1]')
vault operator unseal $(cat /vault-init/vault-init.json | jq -r '.unseal_keys_b64[2]')

echo "Vault status after unsealing:"
vault status

export VAULT_TOKEN=$(cat /vault-init/vault-init.json | jq -r '.root_token')
echo ""
echo "✅ Vault is unsealed and ready to use."
echo "VAULT_ADDR: $VAULT_ADDR"
echo "VAULT_TOKEN: $VAULT_TOKEN"