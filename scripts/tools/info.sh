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
echo "Vault CLI:        source .env && vault status"
echo "Elasticsearch:    https://localhost:9200"
echo "Kibana:           http://localhost:5601"
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
# Get Elasticsearch password from Kubernetes secret
NAMESPACE="${NAMESPACE:-vault-stack}"
ES_PASSWORD=$(kubectl get secret elasticsearch-es-elastic-user -n "$NAMESPACE" -o jsonpath='{.data.elastic}' 2>/dev/null | base64 -d)
if [ -n "$ES_PASSWORD" ]; then
  echo -e "${GREEN}Elasticsearch:    elastic / $ES_PASSWORD${NC}"
  echo -e "${GREEN}Kibana:           elastic / $ES_PASSWORD${NC}"
else
  echo -e "${YELLOW}Elasticsearch:    Run 'task up' first${NC}"
  echo -e "${YELLOW}Kibana:           Run 'task up' first${NC}"
fi
echo "Grafana:          admin / admin"
echo ""
echo -e "${BLUE}Note:${NC}"
echo "-----"
echo "Port-forwarding is active'"
echo "Ensure you Source Vault env via: source .env"
