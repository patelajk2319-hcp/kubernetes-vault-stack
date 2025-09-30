#!/usr/bin/env bash
set -o pipefail

export VAULT_ADDR=http://vault:8200

echo "Checking Vault status..."
vault status || true

echo "Initializing Vault..."
vault operator init -format=json | tee /vault-init/vault-init.json

echo "Waiting for Vault to initialize..."
sleep 10

echo "Unsealing Vault..."
export VAULT_TOKEN=$(cat /vault-init/vault-init.json | jq -r '.root_token')
vault operator unseal $(cat /vault-init/vault-init.json | jq -r '.unseal_keys_b64[0]')
vault operator unseal $(cat /vault-init/vault-init.json | jq -r '.unseal_keys_b64[1]')
vault operator unseal $(cat /vault-init/vault-init.json | jq -r '.unseal_keys_b64[2]')

echo "Checking Vault status after unsealing..."
vault status

echo "Enabling audit logs..."
# Elastic Agent needs 644 permissions (owner read/write, group/others read) to collect logs
vault audit enable -path="audit_log" file file_path=/vault/logs/vault_audit.log mode=644
vault audit enable -path="audit_stdout" file file_path=stdout

echo "✅ Vault initialized, unsealed and audit logs enabled"
echo ""
echo "IMPORTANT: Save the vault-init.json file - it contains the unseal keys and root token!"