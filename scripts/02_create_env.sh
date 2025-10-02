#!/bin/bash

# Create and update .env file with configuration
# This script creates the .env file with Vault, Elasticsearch, and Kibana configuration

set -e

# Source centralized color configuration
source "$(dirname "$0")/lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"
ENV_FILE=".env"

# Create .env file if it doesn't exist
if [ ! -f "$ENV_FILE" ]; then
  echo -e "${BLUE}Creating .env file${NC}"

  # Read Vault license from file if it exists
  LICENSE_FILE="licenses/vault-enterprise/license.lic"
  if [ -f "$LICENSE_FILE" ]; then
    VAULT_LICENSE=$(cat "$LICENSE_FILE" | tr -d '[:space:]')
  else
    VAULT_LICENSE=""
  fi

  cat > "$ENV_FILE" <<EOF
# Vault Configuration
export VAULT_ADDR=http://127.0.0.1:8200

# Vault Enterprise license - Read from licenses/vault-enterprise/license.lic
export VAULT_LICENSE=${VAULT_LICENSE}

# Vault root token - dynamically generated during 'task init'
export VAULT_TOKEN=placeholder
EOF
  echo -e "${GREEN}.env file created${NC}"
fi
