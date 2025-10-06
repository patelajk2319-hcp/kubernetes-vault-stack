#!/bin/bash

# Install HashiCorp Vault integration in Fleet (ELK)
# This script installs the Vault integration to collect:
# - Audit logs: /vault/logs/vault_audit.log
# - Operational logs: /vault/logs/*.json
# - Metrics: http://vault-stack:8200/v1/sys/metrics (if token provided)

set -e

# Source centralised colour configuration
source "$(dirname "$0")/lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"
KIBANA_HOST="${KIBANA_HOST:-https://localhost:5601}"
KIBANA_USER="${KIBANA_USER:-elastic}"

# Source .env file to get VAULT_TOKEN
if [ ! -f ".env" ]; then
  echo -e "${RED}Error: .env file not found. Please run 'task init' first${NC}"
  exit 1
fi
source .env

# Helper function for Fleet API calls
fleet_api() {
  local method=$1
  local endpoint=$2
  local data=$3

  curl -k -s -X "$method" "$KIBANA_HOST$endpoint" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -u "$KIBANA_USER:$KIBANA_PASSWORD" \
    ${data:+-d "$data"}
}

echo -e "${BLUE}=== Installing HashiCorp Vault Integration ===${NC}"

# Get Kibana password from Kubernetes secret
echo -e "${BLUE}Retrieving Kibana password...${NC}"
KIBANA_PASSWORD=$(kubectl get secret -n "$NAMESPACE" elasticsearch-es-elastic-user -o jsonpath='{.data.elastic}' 2>/dev/null | base64 -D)

if [ -z "$KIBANA_PASSWORD" ]; then
    echo -e "${RED}Error: Could not retrieve Kibana password${NC}"
    exit 1
fi

# Check Vault token availability
ENABLE_METRICS=false
if [ -n "$VAULT_TOKEN" ] && [ "$VAULT_TOKEN" != "placeholder" ]; then
    ENABLE_METRICS=true
    echo -e "${BLUE}Vault token detected - will attempt to include metrics${NC}"
    echo -e "${BLUE}Token: ${VAULT_TOKEN:0:10}...${NC}"
else
    echo -e "${BLUE}No Vault token provided - installing logs only${NC}"
fi

# Check if Kibana is accessible
echo -e "${BLUE}Checking Kibana connectivity...${NC}"
if ! fleet_api GET "/api/status" > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to Kibana at $KIBANA_HOST${NC}"
    echo -e "${BLUE}Ensure Kibana port-forward is active: kubectl port-forward -n $NAMESPACE svc/kibana-kb-http 5601:5601${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Kibana is accessible${NC}"

# Get the Default Agent Policy ID
echo -e "${BLUE}Finding Default Agent Policy...${NC}"
POLICY_RESPONSE=$(fleet_api GET "/api/fleet/agent_policies")

# Try to find "Default Agent Policy" or "Default policy" (case-insensitive for "policy")
POLICY_ID=$(echo "$POLICY_RESPONSE" | grep -o '"id":"[^"]*"[^}]*"name":"Default Agent Policy"' | head -1 | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

# Fallback to "Default policy" if "Default Agent Policy" not found
if [ -z "$POLICY_ID" ]; then
    POLICY_ID=$(echo "$POLICY_RESPONSE" | grep -o '"id":"[^"]*"[^}]*"name":"Default [pP]olicy"' | head -1 | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
fi

if [ -z "$POLICY_ID" ]; then
    echo -e "${RED}Error: Could not find Default Agent Policy${NC}"
    echo -e "${BLUE}Available policies:${NC}"
    echo "$POLICY_RESPONSE" | jq -r '.items[] | "  - \(.name) (ID: \(.id))"' 2>/dev/null || echo "No policies found"
    exit 1
fi

echo -e "${GREEN}✓ Found Default Agent Policy ID: $POLICY_ID${NC}"

# Check if Vault integration already exists
echo -e "${BLUE}Checking if Vault integration already exists...${NC}"
EXISTING=$(fleet_api GET "/api/fleet/package_policies" | grep -o '"name":"hashicorp_vault-[^"]*"' | head -1)

if [ -n "$EXISTING" ]; then
    echo -e "${YELLOW}⚠️  Vault integration already exists: $EXISTING${NC}"
    echo -e "${BLUE}To reinstall, first remove the existing integration from Kibana Fleet UI${NC}"
    exit 0
fi

# Install HashiCorp Vault package
echo -e "${BLUE}Installing HashiCorp Vault package...${NC}"
PACKAGE_RESPONSE=$(fleet_api POST "/api/fleet/epm/packages/hashicorp_vault")

if echo "$PACKAGE_RESPONSE" | grep -q "error"; then
    echo -e "${YELLOW}⚠️  Package may already be installed${NC}"
else
    echo -e "${GREEN}✓ Vault package installed${NC}"
fi

sleep 3

# Build log streams JSON (common for both configs)
LOG_STREAMS='[
  {
    "id": "logfile-hashicorp_vault.audit-'"$POLICY_ID"'",
    "enabled": true,
    "data_stream": {"type": "logs", "dataset": "hashicorp_vault.audit"},
    "vars": {
      "paths": {"value": ["/vault/logs/vault_audit.log"], "type": "text"},
      "tags": {"value": ["hashicorp-vault-audit"], "type": "text"},
      "exclude_files": {"value": ["\\.gz$"], "type": "text"},
      "preserve_original_event": {"value": false, "type": "bool"}
    }
  },
  {
    "id": "logfile-hashicorp_vault.log-'"$POLICY_ID"'",
    "enabled": true,
    "data_stream": {"type": "logs", "dataset": "hashicorp_vault.log"},
    "vars": {
      "paths": {"value": ["/vault/logs/*.json"], "type": "text"},
      "tags": {"value": ["hashicorp-vault-log"], "type": "text"},
      "exclude_files": {"value": ["\\.gz$"], "type": "text"},
      "preserve_original_event": {"value": false, "type": "bool"}
    }
  }
]'

# Build metrics input JSON if enabled
METRICS_INPUT=""
if [ "$ENABLE_METRICS" = true ]; then
    METRICS_INPUT=',{
    "type": "prometheus/metrics",
    "policy_template": "metrics",
    "enabled": true,
    "streams": [{
      "id": "prometheus/metrics-hashicorp_vault.metrics-'"$POLICY_ID"'",
      "enabled": true,
      "data_stream": {"type": "metrics", "dataset": "hashicorp_vault.metrics"},
      "vars": {
        "hosts": {"value": ["http://vault-stack:8200"], "type": "text"},
        "metrics_path": {"value": "/v1/sys/metrics", "type": "text"},
        "period": {"value": "30s", "type": "text"},
        "query": {"value": {"format": "prometheus"}, "type": "yaml"},
        "vault_token": {"value": "'"$VAULT_TOKEN"'", "type": "password"}
      }
    }]
  }'
fi

# Create integration with conditional metrics
echo -e "${BLUE}Creating Vault integration...${NC}"
INTEGRATION_PAYLOAD='{
  "name": "hashicorp_vault-1",
  "description": "HashiCorp Vault integration for audit logs, operational logs'"$([ "$ENABLE_METRICS" = true ] && echo ', and metrics' || echo '')"'",
  "namespace": "default",
  "policy_id": "'"$POLICY_ID"'",
  "package": {"name": "hashicorp_vault", "version": "1.28.1"},
  "inputs": [
    {"type": "logfile", "policy_template": "log", "enabled": true, "streams": '"$LOG_STREAMS"'}
    '"$METRICS_INPUT"'
  ]
}'

INTEGRATION_RESPONSE=$(fleet_api POST "/api/fleet/package_policies" "$INTEGRATION_PAYLOAD")

# Check result
if echo "$INTEGRATION_RESPONSE" | grep -q '"id"'; then
    INTEGRATION_ID=$(echo "$INTEGRATION_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo -e "${GREEN}✓ HashiCorp Vault integration created successfully!${NC}"
    echo -e "${BLUE}Integration ID: $INTEGRATION_ID${NC}"
    echo -e "${BLUE}Policy ID: $POLICY_ID${NC}"
    METRICS_ENABLED="$ENABLE_METRICS"
else
    # Fallback: try without metrics if metrics were attempted
    if [ "$ENABLE_METRICS" = true ]; then
        echo -e "${YELLOW}⚠️  Failed with metrics, retrying logs-only...${NC}"
        METRICS_INPUT=""
        INTEGRATION_PAYLOAD='{
          "name": "hashicorp_vault-1",
          "description": "HashiCorp Vault integration for audit and operational logs",
          "namespace": "default",
          "policy_id": "'"$POLICY_ID"'",
          "package": {"name": "hashicorp_vault", "version": "1.28.1"},
          "inputs": [{"type": "logfile", "policy_template": "log", "enabled": true, "streams": '"$LOG_STREAMS"'}]
        }'
        INTEGRATION_RESPONSE=$(fleet_api POST "/api/fleet/package_policies" "$INTEGRATION_PAYLOAD")

        if echo "$INTEGRATION_RESPONSE" | grep -q '"id"'; then
            INTEGRATION_ID=$(echo "$INTEGRATION_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
            echo -e "${GREEN}✓ Integration created with logs only${NC}"
            echo -e "${BLUE}Integration ID: $INTEGRATION_ID${NC}"
            METRICS_ENABLED=false
        else
            echo -e "${RED}❌ Failed to create HashiCorp Vault integration${NC}"
            echo -e "${BLUE}Response: $INTEGRATION_RESPONSE${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ Failed to create HashiCorp Vault integration${NC}"
        echo -e "${BLUE}Response: $INTEGRATION_RESPONSE${NC}"
        exit 1
    fi
fi

# Summary output
echo ""
echo -e "${GREEN}=== Integration Installation Complete ===${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo -e "${BLUE}- Audit logs: /vault/logs/vault_audit.log${NC}"
echo -e "${BLUE}- Operation logs: /vault/logs/*.json${NC}"

if [ "$METRICS_ENABLED" = true ]; then
    echo -e "${GREEN}- Metrics: Enabled (http://vault-stack:8200)${NC}"
else
    echo -e "${BLUE}- Metrics: Disabled${NC}"
    [ -n "$VAULT_TOKEN" ] && [ "$VAULT_TOKEN" != "placeholder" ] && \
        echo -e "${YELLOW}  (Can be enabled manually in Kibana Fleet UI)${NC}"
fi

echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "${BLUE}1. Wait 1-2 minutes for the agent to receive the new policy${NC}"
echo -e "${BLUE}2. Generate Vault activity to create audit logs:${NC}"
echo -e "${BLUE}   kubectl exec -n $NAMESPACE vault-stack-0 -- vault kv put secret/test key=value${NC}"
echo -e "${BLUE}3. Check logs in Kibana Discover: logs-hashicorp_vault.audit-*${NC}"
[ "$METRICS_ENABLED" = true ] && echo -e "${BLUE}4. Check metrics in Kibana Discover: metrics-hashicorp_vault.metrics-*${NC}"

echo ""
echo -e "${BLUE}Verification commands:${NC}"
echo -e "${BLUE}- Agent status: kubectl logs -n $NAMESPACE -l agent.k8s.elastic.co/name=elastic-agent${NC}"
echo -e "${BLUE}- Check indices: curl -k -u elastic:$KIBANA_PASSWORD 'https://localhost:9200/_cat/indices/logs-vault*?v'${NC}"
