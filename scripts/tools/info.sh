#!/bin/bash

# Display access information and credentials for all services

# Source centralised colour configuration
source "$(dirname "$0")/../lib/colors.sh"

echo -e "${BLUE}===================================${NC}"
echo -e "${BLUE}  Vault Stack Access Information${NC}"
echo -e "${BLUE}===================================${NC}"
echo ""
echo -e "${BLUE}Services:${NC}"
echo "---------"
echo "Vault UI:         http://localhost:8200/ui"
echo "Elasticsearch:    https://localhost:9200"
echo "Kibana:           https://localhost:5601"
echo "Grafana:          http://localhost:3000"
echo "Prometheus:       http://localhost:9090"
echo ""
echo -e "${BLUE}Credentials:${NC}"
echo "------------"
if [ -f vault-init.json ]; then
  echo -e "${GREEN}Vault Token:      $(cat vault-init.json | jq -r '.root_token')${NC}"
  echo -e "${GREEN}Vault Unseal Key: $(cat vault-init.json | jq -r '.unseal_keys_b64[0]')${NC}"
else
  echo -e "${YELLOW}Vault:            Run 'task init' first${NC}"
fi
# ELK stack credentials (Podman)
if podman ps --format "{{.Names}}" 2>/dev/null | grep -q "^k8s_vault_elasticsearch"; then
  echo -e "${GREEN}Elasticsearch:    elastic / password123${NC}"
  echo -e "${GREEN}Kibana:           elastic / password123${NC}"
else
  echo -e "${YELLOW}Elasticsearch:    Run 'task up' first${NC}"
  echo -e "${YELLOW}Kibana:           Run 'task up' first${NC}"
fi

# Dynamic Elasticsearch credentials (VSO)
NAMESPACE="${NAMESPACE:-vault-stack}"
if kubectl get secret elasticsearch-dynamic-secret -n "$NAMESPACE" &>/dev/null; then
  ES_USERNAME=$(kubectl get secret elasticsearch-dynamic-secret -n "$NAMESPACE" -o jsonpath='{.data.username}' 2>/dev/null | base64 -d)
  ES_PASSWORD=$(kubectl get secret elasticsearch-dynamic-secret -n "$NAMESPACE" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
  echo ""
  echo -e "${BLUE}Dynamic Credentials (Vault Secrets Operator):${NC}"
  echo "----------------------------------------------"
  echo -e "${GREEN}ES Username:      $ES_USERNAME${NC}"
  echo -e "${GREEN}ES Password:      $ES_PASSWORD${NC}"
  echo -e "${YELLOW}Note: Credentials rotate every 5 minutes${NC}"
else
  echo ""
  echo -e "${YELLOW}Dynamic Demo:     Run 'task elk:dynamic' to deploy${NC}"
fi
echo -e "${GREEN}Grafana:          admin / admin${NC}"
echo ""
echo -e "${BLUE}Note:${NC}"
echo "-----"
echo "Port-forwarding is active'"
echo "Ensure you Source Vault env via: source .env"
