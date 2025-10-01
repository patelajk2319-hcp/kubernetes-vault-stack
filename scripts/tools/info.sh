#!/bin/bash

# Display access information and credentials for all services

# Source centralized color configuration
source "$(dirname "$0")/../lib/colors.sh"

echo -e "${BLUE}===================================${NC}"
echo -e "${BLUE}  Vault Stack Access Information${NC}"
echo -e "${BLUE}===================================${NC}"
echo ""
echo -e "${BLUE}Services:${NC}"
echo "---------"
echo "Vault UI:         http://localhost:8200/ui"
echo "Vault CLI:        source .env && vault status"
echo "Elasticsearch:    https://localhost:9200"
echo "Kibana:           https://localhost:5601"
echo "Grafana:          http://localhost:3000"
echo "Prometheus:       http://localhost:9090"
echo "Redis:            localhost:6379"
echo ""
echo -e "${BLUE}Credentials:${NC}"
echo "------------"
if [ -f vault-init.json ]; then
  echo -e "${GREEN}Vault Token:      $(cat vault-init.json | jq -r '.root_token')${NC}"
  echo -e "${GREEN}Vault Unseal Key: $(cat vault-init.json | jq -r '.unseal_keys_b64[0]')${NC}"
else
  echo -e "${YELLOW}Vault:            Run 'task init' first${NC}"
fi
echo "Elasticsearch:    elastic / password123"
echo "Kibana:           elastic / password123"
echo "Grafana:          admin / admin"
echo "Redis:            vault-root-user / SuperSecretPass123"
echo ""
echo -e "${BLUE}Note:${NC}"
echo "-----"
echo "Port-forwarding is active'"
echo "Ensure you Source Vault env via: source .env"
