#!/usr/bin/env bash
set -euo pipefail

# Colour codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

# Configuration
NAMESPACE="${NAMESPACE:-vault-stack}"
VAULT_POD="${VAULT_POD:-vault-stack-0}"

# Load Vault token from .env
if [ -f ".env" ]; then
  source .env
else
  echo -e "${RED}Error: .env file not found${NC}"
  exit 1
fi

if [ -z "${VAULT_TOKEN:-}" ]; then
  echo -e "${RED}Error: VAULT_TOKEN not set in .env${NC}"
  exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Creating Vault Sample Data${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# 1. Enable KV v2 secrets engine and create sample secrets
echo -e "${BLUE}Enabling KV v2 secrets engine...${NC}"
kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- \
  env VAULT_TOKEN="$VAULT_TOKEN" \
  vault secrets enable -path=secret kv-v2 2>/dev/null || echo -e "${YELLOW}KV v2 engine already enabled${NC}"

echo -e "${BLUE}Creating sample secrets...${NC}"

kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- \
  env VAULT_TOKEN="$VAULT_TOKEN" \
  vault kv put secret/database/config \
  username=db_admin \
  password=SuperSecret123 \
  host=postgres.example.com \
  port=5432

kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- \
  env VAULT_TOKEN="$VAULT_TOKEN" \
  vault kv put secret/api/credentials \
  api_key=sk_live_abc123xyz789 \
  api_secret=secret_key_def456 \
  environment=production

kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- \
  env VAULT_TOKEN="$VAULT_TOKEN" \
  vault kv put secret/app/config \
  environment=production \
  debug=false \
  max_connections=100

echo -e "${GREEN}✓ KV v2 engine enabled with 3 sample secrets${NC}"
echo

# 2. Enable database secrets engine
echo -e "${BLUE}Enabling database secrets engine...${NC}"
kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- \
  env VAULT_TOKEN="$VAULT_TOKEN" \
  vault secrets enable -path=database database 2>/dev/null || echo -e "${YELLOW}Database engine already enabled${NC}"

echo -e "${GREEN}✓ Database secrets engine enabled${NC}"
echo

# 3. Enable userpass authentication
echo -e "${BLUE}Enabling userpass authentication...${NC}"
kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- \
  env VAULT_TOKEN="$VAULT_TOKEN" \
  vault auth enable userpass 2>/dev/null || echo -e "${YELLOW}Userpass auth already enabled${NC}"

echo -e "${GREEN}✓ Userpass authentication enabled${NC}"
echo

# 4. Generate some activity for audit logs
echo -e "${BLUE}Generating activity for audit logs...${NC}"

# Read some secrets
kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- \
  env VAULT_TOKEN="$VAULT_TOKEN" \
  vault kv get secret/database/config >/dev/null 2>&1

kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- \
  env VAULT_TOKEN="$VAULT_TOKEN" \
  vault kv get secret/api/credentials >/dev/null 2>&1

# List secrets
kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- \
  env VAULT_TOKEN="$VAULT_TOKEN" \
  vault kv list secret/ >/dev/null 2>&1

echo -e "${GREEN}✓ Generated sample activity${NC}"
echo

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Sample Data Creation Complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo
echo -e "${GREEN}Summary:${NC}"
echo -e "  - KV v2 secrets engine enabled at: secret/"
echo -e "  - Database secrets engine enabled at: database/"
echo -e "  - Userpass auth method enabled"
echo -e "  - 3 sample secrets created"
echo -e "  - Audit logs generated for all operations"
echo
