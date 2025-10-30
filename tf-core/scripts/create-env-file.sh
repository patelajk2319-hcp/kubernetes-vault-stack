#!/bin/bash

# Create .env file with Vault configuration
# This script is called by Terraform to generate the .env file

set -e

VAULT_LICENSE="$1"
ENV_FILE="$2"

if [ -z "$VAULT_LICENSE" ] || [ -z "$ENV_FILE" ]; then
  echo "Usage: $0 <vault_license> <env_file_path>"
  exit 1
fi

cat > "$ENV_FILE" <<EOF
# Vault Configuration
export VAULT_ADDR=http://127.0.0.1:8200

# Vault Enterprise license - Read from licenses/vault-enterprise/license.lic
export VAULT_LICENSE=$VAULT_LICENSE

# Vault root token - dynamically generated during 'task init'
export VAULT_TOKEN=placeholder
EOF

chmod 0600 "$ENV_FILE"

echo "Created $ENV_FILE"
