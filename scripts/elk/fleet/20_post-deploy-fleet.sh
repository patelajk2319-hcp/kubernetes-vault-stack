#!/bin/bash
# Post-deployment configuration for Elastic Fleet
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ELASTIC_AGENT_CONTAINER="k8s_vault_elastic_agent"
FLEET_SERVER_CONTAINER="k8s_vault_fleet_server"

echo -e "${BLUE}Starting post-deployment Fleet configuration${NC}"
check_service() {
    local service_name=$1
    local url=$2
    local max_attempts=$3

    echo -e "${BLUE}Checking $service_name...${NC}"
    for i in $(seq 1 "$max_attempts"); do
        if curl -k -s --connect-timeout 5 "$url" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ $service_name is ready${NC}"
            return 0
        fi
        echo -e "${YELLOW}   Attempt $i/$max_attempts - $service_name not ready...${NC}"
        sleep 10
    done
    echo -e "${YELLOW}❌ $service_name failed to become ready${NC}"
    return 1
}

if ! check_service "Fleet Server" "http://localhost:8220/api/status" 10; then
    echo -e "${YELLOW}❌ Fleet Server is not responding. Check logs: podman logs k8s_vault_fleet_server${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Fleet Server is healthy${NC}"

echo -e "${BLUE}Checking Elastic Agent enrolment status${NC}"
AGENT_STATUS=$(podman exec "$ELASTIC_AGENT_CONTAINER" elastic-agent status 2>/dev/null || echo "ERROR")

if echo "$AGENT_STATUS" | grep -q "Connected"; then
    echo -e "${GREEN}✅ Elastic Agent is already enrolled and connected${NC}"
else
    echo -e "${BLUE}Enroling Elastic Agent${NC}"
    TOKEN=$(cat ./fleet-tokens/enrollment-token 2>/dev/null)

    if [ -z "$TOKEN" ]; then
        echo -e "${YELLOW}❌ No enrolment token found${NC}"
        exit 1
    fi

    echo -e "${BLUE}Found enrolment token${NC}"
    if podman exec "$ELASTIC_AGENT_CONTAINER" elastic-agent enroll \
        --url=http://fleet-server:8220 \
        --enrollment-token="$TOKEN" \
        --insecure \
        --force; then
        echo -e "${GREEN}✅ Elastic Agent enrolled successfully${NC}"
    else
        echo -e "${YELLOW}❌ Failed to enrol Elastic Agent${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}Verifying agents in Kibana${NC}"
AGENTS_RESPONSE=$(curl -k -s -X GET "https://localhost:5601/api/fleet/agents" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -u "elastic:password123" \
    --cacert certs/ca/ca.crt 2>/dev/null)

if echo "$AGENTS_RESPONSE" | grep -q '"status":"online"'; then
    AGENT_COUNT=$(echo "$AGENTS_RESPONSE" | grep -o '"status":"online"' | wc -l)
    echo -e "${GREEN}✅ Found $AGENT_COUNT online agent(s) in Kibana${NC}"
    echo -e "${BLUE}Agent Details:${NC}"
    echo "$AGENTS_RESPONSE" | jq -r '.list[] | "  - ID: \(.id) | Status: \(.status) | Type: \(.type) | Policy: \(.policy_id)"' 2>/dev/null || echo "  (Raw response parsing failed, but agents are online)"
else
    echo -e "${YELLOW}⚠️  No online agents found in Kibana${NC}"
fi

echo -e "${BLUE}Waiting for agent daemon to stabilise${NC}"
sleep 10

echo -e "${BLUE}Final status verification${NC}"
echo -e "${BLUE}Fleet Server Status:${NC}"
if podman exec "$FLEET_SERVER_CONTAINER" elastic-agent status 2>/dev/null; then
    echo -e "${GREEN}✅ Fleet Server status check successful${NC}"
else
    echo -e "${YELLOW}⚠️  Fleet Server status check failed (may be restarting)${NC}"
fi

echo ""
echo -e "${BLUE}Elastic Agent Status:${NC}"
AGENT_STATUS_SUCCESS=false
for i in {1..3}; do
    if podman exec "$ELASTIC_AGENT_CONTAINER" elastic-agent status 2>/dev/null; then
        echo -e "${GREEN}✅ Elastic Agent status check successful${NC}"
        AGENT_STATUS_SUCCESS=true
        break
    else
        echo -e "${YELLOW}⚠️  Elastic Agent status check attempt $i/3: daemon may be restarting...${NC}"
        if [ "$i" -lt 3 ]; then
            sleep 5
        fi
    fi
done

if [ "$AGENT_STATUS_SUCCESS" = false ]; then
    echo -e "${YELLOW}Note: Agent daemon may be restarting after enrolment${NC}"
fi

echo ""
echo -e "${GREEN}Post-deployment Fleet setup completed!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "${BLUE}  1. Check Kibana Fleet dashboard: https://localhost:5601/app/fleet${NC}"
echo -e "${BLUE}  2. Configure Vault audit logging to send logs to Elasticsearch${NC}"
echo -e "${BLUE}  3. Set up log collection policies in Fleet${NC}"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo -e "${BLUE}  - Check Fleet agents: curl -k https://localhost:5601/api/fleet/agents -H 'kbn-xsrf: true' -u elastic:password123 --cacert certs/ca/ca.crt${NC}"
echo -e "${BLUE}  - View agent logs: podman logs k8s_vault_elastic_agent${NC}"
echo -e "${BLUE}  - View agent status: podman exec k8s_vault_elastic_agent elastic-agent status${NC}"
echo -e "${BLUE}  - Fleet Server status: curl -k http://localhost:8220/api/status${NC}"