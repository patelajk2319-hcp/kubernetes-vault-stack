#!/bin/sh
# Fleet initialization script for Kubernetes
# This script sets up Fleet in Kibana, creates policies, and generates tokens

set -e

echo "Initializing Fleet setup..."

# Wait for Kibana to be ready
echo "Waiting for Kibana to be ready..."
for i in $(seq 1 60); do
    if curl -k -s --fail -u "${KIBANA_USER}:${KIBANA_PASSWORD}" \
       "${KIBANA_HOST}/api/status" > /dev/null 2>&1; then
        echo "Kibana is ready!"
        break
    fi
    echo "   Attempt $i/60 - Kibana not ready yet, waiting..."
    sleep 5
done

# Initialise Fleet
echo "Setting up Fleet..."
curl -k -s -X POST "${KIBANA_HOST}/api/fleet/setup" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -u "${KIBANA_USER}:${KIBANA_PASSWORD}" || echo "Fleet may already be initialised"

sleep 5

# Configure default Elasticsearch output
echo "Configuring default Elasticsearch output..."
curl -k -s -X POST "${KIBANA_HOST}/api/fleet/outputs" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -u "${KIBANA_USER}:${KIBANA_PASSWORD}" \
  -d "{
    \"id\": \"fleet-default-output\",
    \"name\": \"default\",
    \"type\": \"elasticsearch\",
    \"is_default\": true,
    \"hosts\": [\"${ELASTICSEARCH_HOST}\"],
    \"config_yaml\": \"ssl.verification_mode: none\"
  }" || echo "Default output may already exist - attempting update..."

curl -k -s -X PUT "${KIBANA_HOST}/api/fleet/outputs/fleet-default-output" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -u "${KIBANA_USER}:${KIBANA_PASSWORD}" \
  -d "{
    \"name\": \"default\",
    \"type\": \"elasticsearch\",
    \"hosts\": [\"${ELASTICSEARCH_HOST}\"],
    \"config_yaml\": \"ssl.verification_mode: none\"
  }" || echo "Output configuration update completed"

sleep 3

# Create Fleet Server service token using Elasticsearch API directly
echo "Creating Fleet Server service token..."
# Use Elasticsearch API directly to create service token
FLEET_TOKEN_RESPONSE=$(curl -k -s -X POST "${ELASTICSEARCH_HOST}/_security/service/elastic/fleet-server/credential/token/fleet-server-token-1" \
  -H "Content-Type: application/json" \
  -u "${KIBANA_USER}:${KIBANA_PASSWORD}")

if echo "$FLEET_TOKEN_RESPONSE" | grep -q "value"; then
    FLEET_SERVER_TOKEN=$(echo "$FLEET_TOKEN_RESPONSE" | grep -o '"value":"[^"]*"' | cut -d'"' -f4)
    kubectl create secret generic fleet-server-token -n ${NAMESPACE} --from-literal=token="$FLEET_SERVER_TOKEN" --dry-run=client -o yaml | kubectl apply -f -
    echo "Fleet Server token created and saved to secret"
else
    echo "Failed to create Fleet Server token via Elasticsearch API, trying Kibana API..."
    # Fallback to Kibana API
    FLEET_TOKEN_RESPONSE=$(curl -k -s -X POST "${KIBANA_HOST}/api/fleet/service-tokens" \
      -H "kbn-xsrf: true" \
      -H "Content-Type: application/json" \
      -H "elastic-api-version: 1" \
      -u "${KIBANA_USER}:${KIBANA_PASSWORD}")

    if echo "$FLEET_TOKEN_RESPONSE" | grep -q "value"; then
        FLEET_SERVER_TOKEN=$(echo "$FLEET_TOKEN_RESPONSE" | grep -o '"value":"[^"]*"' | cut -d'"' -f4)
        kubectl create secret generic fleet-server-token -n ${NAMESPACE} --from-literal=token="$FLEET_SERVER_TOKEN" --dry-run=client -o yaml | kubectl apply -f -
        echo "Fleet Server token created via Kibana API and saved to secret"
    else
        echo "Failed to create Fleet Server token"
        echo "Response: $FLEET_TOKEN_RESPONSE"
        exit 1
    fi
fi

# Install Fleet Server package
echo "Installing Fleet Server package..."
curl -k -s -X POST "${KIBANA_HOST}/api/fleet/epm/packages/fleet_server/1.6.0" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -u "${KIBANA_USER}:${KIBANA_PASSWORD}" || echo "Package may already be installed"

sleep 3

# Create Fleet Server policy
echo "Creating Fleet Server policy..."
FLEET_SERVER_POLICY_RESPONSE=$(curl -k -s -X POST "${KIBANA_HOST}/api/fleet/agent_policies" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -u "${KIBANA_USER}:${KIBANA_PASSWORD}" \
  -d '{
    "id": "fleet-server-policy",
    "name": "Fleet Server Policy",
    "description": "Policy for Fleet Server",
    "namespace": "default",
    "monitoring_enabled": ["logs", "metrics"],
    "is_default_fleet_server": true
  }')

echo "Fleet Server policy response: $FLEET_SERVER_POLICY_RESPONSE"

sleep 3

# Add Fleet Server integration to the policy
echo "Adding Fleet Server integration to policy..."
curl -k -s -X POST "${KIBANA_HOST}/api/fleet/package_policies" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -u "${KIBANA_USER}:${KIBANA_PASSWORD}" \
  -d '{
    "name": "fleet_server-1",
    "description": "Fleet Server integration",
    "namespace": "default",
    "policy_id": "fleet-server-policy",
    "package": {
      "name": "fleet_server",
      "version": "1.6.0"
    },
    "inputs": [
      {
        "type": "fleet-server",
        "enabled": true,
        "streams": [],
        "vars": {
          "host": {
            "value": "0.0.0.0",
            "type": "text"
          },
          "port": {
            "value": 8220,
            "type": "integer"
          }
        }
      }
    ]
  }' || echo "Integration may already exist"

sleep 3

# Create Default Agent policy
echo "Creating Default Agent policy..."
AGENT_POLICY_RESPONSE=$(curl -k -s -X POST "${KIBANA_HOST}/api/fleet/agent_policies" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -u "${KIBANA_USER}:${KIBANA_PASSWORD}" \
  -d '{
    "name": "Default Agent Policy",
    "description": "Default policy for Elastic Agents",
    "namespace": "default",
    "monitoring_enabled": ["logs", "metrics"]
  }')

echo "Agent policy response: $AGENT_POLICY_RESPONSE"

# Extract policy ID
POLICY_ID=$(echo "$AGENT_POLICY_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

# If creation failed, get existing policy
if [ -z "$POLICY_ID" ] && echo "$AGENT_POLICY_RESPONSE" | grep -q "409"; then
    echo "Policy already exists, fetching existing policy..."
    EXISTING_POLICIES=$(curl -k -s -X GET "${KIBANA_HOST}/api/fleet/agent_policies" \
      -H "kbn-xsrf: true" \
      -u "${KIBANA_USER}:${KIBANA_PASSWORD}")

    POLICY_ID=$(echo "$EXISTING_POLICIES" | grep -o '"id":"[^"]*"[^}]*"name":"Default Agent Policy"' | head -1 | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
fi

echo "Using agent policy with ID: $POLICY_ID"

if [ -z "$POLICY_ID" ]; then
    echo "Failed to get policy ID"
    exit 1
fi

sleep 3

# Create enrollment token
echo "Creating enrollment token..."
ENROLLMENT_RESPONSE=$(curl -k -s -X POST "${KIBANA_HOST}/api/fleet/enrollment-api-keys" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -H "elastic-api-version: 1" \
  -u "${KIBANA_USER}:${KIBANA_PASSWORD}" \
  -d "{\"policy_id\": \"$POLICY_ID\"}")

if echo "$ENROLLMENT_RESPONSE" | grep -q '"api_key"'; then
    ENROLLMENT_TOKEN=$(echo "$ENROLLMENT_RESPONSE" | grep -o '"api_key":"[^"]*"' | cut -d'"' -f4)
    kubectl create secret generic elastic-agent-enrollment-token -n ${NAMESPACE} --from-literal=token="$ENROLLMENT_TOKEN" --dry-run=client -o yaml | kubectl apply -f -
    echo "Enrollment token created and saved to secret"
else
    echo "Failed to create enrollment token"
    echo "Response: $ENROLLMENT_RESPONSE"
    exit 1
fi

echo "Fleet initialisation completed successfully!"
