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
# Use /hosthome mount point that will be set up via minikube mount
VAULT_AUDIT_LOG_PATH="/hosthome/vault-audit-logs"
VAULT_AUDIT_LOG_PATH_HOST="$(pwd)/vault-audit-logs"

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
echo -e "${BLUE}Vault Audit Logging Configuration${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Step 1: Enable file audit logging in Vault
echo -e "${BLUE}Enabling Vault file audit logging...${NC}"
kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- \
  env VAULT_TOKEN="$VAULT_TOKEN" \
  vault audit enable \
  -path="audit_file" \
  file file_path=/tmp/vault_audit.log \
  mode=0644 || echo -e "${YELLOW}Audit logging may already be enabled${NC}"

echo -e "${GREEN}✓ Vault audit logging enabled${NC}"
echo

# Step 2: Set up host path for audit logs (minikube)
echo -e "${BLUE}Setting up audit log collection from Vault pod...${NC}"

# Create local directory for audit logs if it doesn't exist
mkdir -p "$VAULT_AUDIT_LOG_PATH_HOST"

echo -e "${YELLOW}Note: Audit logs will be collected via kubectl cp from Vault pod${NC}"
echo -e "${YELLOW}      Location: ${VAULT_POD}:/tmp/vault_audit.log -> ${VAULT_AUDIT_LOG_PATH}/${NC}"
echo

# Step 3: Configure Fleet integration (requires ELK stack to be running)
echo -e "${BLUE}Configuring Fleet integration...${NC}"
echo

# ELK connection details
KIBANA_HOST="https://localhost:5601"
KIBANA_USER="elastic"
KIBANA_PASSWORD="password123"

# Wait for Kibana to be accessible (up to 2 minutes)
echo -e "${BLUE}Checking Kibana accessibility...${NC}"
KIBANA_ACCESSIBLE=false
for i in {1..24}; do
  if curl -k -s -u "${KIBANA_USER}:${KIBANA_PASSWORD}" "${KIBANA_HOST}/api/status" >/dev/null 2>&1; then
    KIBANA_ACCESSIBLE=true
    echo -e "${GREEN}✓ Kibana is accessible${NC}"
    break
  fi
  if [ $i -eq 1 ]; then
    echo -e "${YELLOW}Kibana not ready yet, waiting...${NC}"
  fi
  echo -ne "${BLUE}\rWaiting: ${i}5s / 120s${NC}"
  sleep 5
done
echo ""

if [ "$KIBANA_ACCESSIBLE" = false ]; then
  echo -e "${RED}Error: Kibana is not accessible at ${KIBANA_HOST}${NC}"
  echo -e "${YELLOW}Please ensure ELK stack is running properly${NC}"
  echo -e "${YELLOW}Check with: task status${NC}"
  exit 1
fi

# Get minikube IP for Vault access
MINIKUBE_IP=$(minikube ip)
echo -e "${BLUE}Minikube IP: ${MINIKUBE_IP}${NC}"

# Get Vault NodePort
VAULT_NODEPORT=$(kubectl get svc -n "$NAMESPACE" vault-nodeport -o jsonpath='{.spec.ports[0].nodePort}')
VAULT_EXTERNAL_URL="http://${MINIKUBE_IP}:${VAULT_NODEPORT}"

echo -e "${BLUE}Vault external URL: ${VAULT_EXTERNAL_URL}${NC}"
echo

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

echo -e "${BLUE}Searching for agent policy...${NC}"
POLICY_RESPONSE=$(fleet_api "GET" "/api/fleet/agent_policies" "")
POLICY_ID=$(echo "$POLICY_RESPONSE" | jq -r '.items[] | select(.name | test("Default"; "i")) | .id' | head -n 1)

if [ -z "$POLICY_ID" ] || [ "$POLICY_ID" = "null" ]; then
  echo -e "${RED}Error: Could not find default agent policy${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Found agent policy: ${POLICY_ID}${NC}"

# Check if HashiCorp Vault integration already exists
echo -e "${BLUE}Checking for existing Vault integration...${NC}"
EXISTING_INTEGRATION=$(fleet_api "GET" "/api/fleet/package_policies" "" | jq -r '.items[] | select(.name == "hashicorp-vault-logs") | .id')

if [ -n "$EXISTING_INTEGRATION" ] && [ "$EXISTING_INTEGRATION" != "null" ]; then
  echo -e "${YELLOW}Vault integration already exists, deleting...${NC}"
  fleet_api "DELETE" "/api/fleet/package_policies/$EXISTING_INTEGRATION" ""
  sleep 2
fi

# Get available HashiCorp Vault integration version
echo -e "${BLUE}Getting HashiCorp Vault integration package info...${NC}"
PACKAGE_INFO=$(fleet_api "GET" "/api/fleet/epm/packages/hashicorp_vault" "")
LATEST_VERSION=$(echo "$PACKAGE_INFO" | jq -r '.item.latestVersion // .response.latestVersion // "1.18.1"')
echo -e "${GREEN}✓ Using version: ${LATEST_VERSION}${NC}"

# Create HashiCorp Vault integration
echo -e "${BLUE}Creating HashiCorp Vault integration...${NC}"

INTEGRATION_PAYLOAD=$(cat <<EOF
{
  "name": "hashicorp-vault-logs",
  "description": "Collect Vault audit logs from Kubernetes via log file",
  "namespace": "default",
  "policy_id": "$POLICY_ID",
  "package": {
    "name": "hashicorp_vault",
    "version": "$LATEST_VERSION"
  },
  "inputs": [
    {
      "type": "logfile",
      "policy_template": "audit",
      "enabled": true,
      "streams": [
        {
          "enabled": true,
          "data_stream": {
            "type": "logs",
            "dataset": "hashicorp_vault.audit"
          },
          "vars": {
            "paths": {"value": ["/mnt/vault-logs/vault_audit.log"], "type": "text"},
            "tags": {"value": ["vault-audit", "kubernetes"], "type": "text"},
            "preserve_original_event": {"value": false, "type": "bool"},
            "processors": {"value": "- add_fields:\\n    target: ''\\n    fields:\\n      ecs.version: 1.12.0\\n", "type": "yaml"}
          }
        }
      ]
    }
  ]
}
EOF
)

INTEGRATION_RESPONSE=$(fleet_api "POST" "/api/fleet/package_policies" "$INTEGRATION_PAYLOAD")
INTEGRATION_ID=$(echo "$INTEGRATION_RESPONSE" | jq -r '.item.id')

if [ -z "$INTEGRATION_ID" ] || [ "$INTEGRATION_ID" = "null" ]; then
  echo -e "${RED}Failed to create Vault integration${NC}"
  echo "$INTEGRATION_RESPONSE" | jq '.'
  exit 1
fi

echo -e "${GREEN}✓ HashiCorp Vault integration created successfully!${NC}"
echo -e "${BLUE}Integration ID: ${INTEGRATION_ID}${NC}"
echo

# Step 4: Set up automatic log syncing via Kubernetes CronJob
echo -e "${BLUE}Setting up automatic log syncing (CronJob)...${NC}"

# Create ServiceAccount, Role, and RoleBinding for log sync
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-log-sync
  namespace: ${NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: vault-log-sync
  namespace: ${NAMESPACE}
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: vault-log-sync
  namespace: ${NAMESPACE}
subjects:
- kind: ServiceAccount
  name: vault-log-sync
  namespace: ${NAMESPACE}
roleRef:
  kind: Role
  name: vault-log-sync
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: vault-audit-log-sync
  namespace: ${NAMESPACE}
spec:
  schedule: "*/2 * * * *"  # Every 2 minutes
  successfulJobsHistoryLimit: 1
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: vault-log-sync
          restartPolicy: OnFailure
          securityContext:
            runAsUser: 0
            fsGroup: 0
          containers:
          - name: sync
            image: bitnami/kubectl:latest
            securityContext:
              runAsUser: 0
            command:
            - /bin/bash
            - -c
            - |
              set -e
              # Copy log from Vault pod to the hostPath-mounted directory
              kubectl cp ${NAMESPACE}/${VAULT_POD}:/tmp/vault_audit.log /sync/vault_audit.log 2>&1 || true

              if [ -f /sync/vault_audit.log ]; then
                chmod 644 /sync/vault_audit.log
                echo "Log synced at \$(date) - \$(wc -l < /sync/vault_audit.log) lines"
              else
                echo "No audit log file yet at \$(date)"
              fi
            volumeMounts:
            - name: audit-logs
              mountPath: /sync
          volumes:
          - name: audit-logs
            hostPath:
              path: ${VAULT_AUDIT_LOG_PATH}
              type: DirectoryOrCreate
EOF

echo -e "${GREEN}✓ Automatic log syncing configured (every 2 minutes)${NC}"
echo

# Initial log sync
echo -e "${BLUE}Performing initial log sync...${NC}"
mkdir -p "$VAULT_AUDIT_LOG_PATH_HOST"
kubectl cp "${NAMESPACE}/${VAULT_POD}:/tmp/vault_audit.log" "${VAULT_AUDIT_LOG_PATH_HOST}/vault_audit.log" 2>/dev/null || echo -e "${YELLOW}No audit log file yet (will be created on first Vault operation)${NC}"
echo -e "${GREEN}✓ Initial sync complete${NC}"
echo

# Final summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Audit Log Collection Setup Complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo
echo -e "${GREEN}✓ Vault audit logging enabled${NC}"
echo -e "${GREEN}✓ Fleet integration configured${NC}"
echo -e "${GREEN}✓ Automatic log syncing active (every 2 minutes)${NC}"
echo
echo -e "${YELLOW}Logs are synced to: ${VAULT_AUDIT_LOG_PATH}/${NC}"
echo -e "${YELLOW}Elastic Agent reads from: ./vault-audit-logs/ (bind mount)${NC}"
echo
echo -e "${GREEN}Access Kibana at: ${KIBANA_HOST}${NC}"
echo -e "${GREEN}Username: ${KIBANA_USER}${NC}"
echo -e "${GREEN}Password: ${KIBANA_PASSWORD}${NC}"
echo
