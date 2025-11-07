#!/bin/bash

# Deploy the entire Vault stack using Terraform

set -euo pipefail

# Source centralised colour configuration
source "$(dirname "$0")/lib/colors.sh"

echo -e "${BLUE}=== Deploying Vault Stack Infrastructure ===${NC}"

# Set up minikube mount for audit logs
echo -e "${BLUE}Setting up minikube mount for audit logs...${NC}"
cd "$(dirname "$0")/.."
./scripts/tools/setup-minikube-mount.sh
echo ""

# Change to tf-core directory
cd "$(dirname "$0")/../terraform/tf-core"

# Initialise Terraform
echo -e "${BLUE}Initialising Terraform...${NC}"
terraform init -upgrade

# Apply Terraform configuration
echo -e "${BLUE}Applying Terraform configuration...${NC}"
terraform apply -auto-approve

echo ""
echo -e "${GREEN}=== Kubernetes Infrastructure Deployed Successfully! ===${NC}"
echo ""

# Deploy ELK stack via podman-compose
cd "$(dirname "$0")/.."
echo -e "${BLUE}=== Deploying ELK Stack (Podman) ===${NC}"
echo ""

# Generate certificates if they don't exist
if [ ! -d "certs/ca" ] || [ ! -f "certs/ca/ca.crt" ]; then
  echo -e "${BLUE}Generating TLS certificates...${NC}"
  ./scripts/elk/00_create-certs.sh
  echo -e "${GREEN}✓ Certificates generated${NC}"
  echo ""
else
  echo -e "${GREEN}✓ Certificates already exist${NC}"
  echo ""
fi

# Start ELK stack
echo -e "${BLUE}Starting ELK stack containers...${NC}"
if podman-compose -f elk-compose.yml up -d; then
  echo ""
  echo -e "${GREEN}✓ ELK stack containers started${NC}"
  echo ""

  # Wait for Elasticsearch to be healthy (up to 3 minutes)
  echo -e "${BLUE}Waiting for Elasticsearch to become healthy...${NC}"
  ELASTICSEARCH_READY=false
  for i in {1..36}; do
    if podman exec k8s_vault_elasticsearch curl -k -s -u elastic:password123 https://localhost:9200/_cluster/health >/dev/null 2>&1; then
      ELASTICSEARCH_READY=true
      echo -e "${GREEN}✓ Elasticsearch is healthy (${i}0s)${NC}"
      break
    fi
    echo -ne "${BLUE}\rWaiting: ${i}0s / 360s${NC}"
    sleep 10
  done
  echo ""

  if [ "$ELASTICSEARCH_READY" = false ]; then
    echo -e "${RED}Elasticsearch did not become healthy within 6 minutes${NC}"
    echo -e "${YELLOW}Check logs with: podman logs k8s_vault_elasticsearch${NC}"
    exit 1
  fi

  # Wait for Kibana to be healthy (up to 3 minutes)
  echo -e "${BLUE}Waiting for Kibana to become healthy...${NC}"
  KIBANA_READY=false
  for i in {1..36}; do
    if podman exec k8s_vault_kibana curl -k -s -f https://localhost:5601/api/status >/dev/null 2>&1; then
      KIBANA_READY=true
      echo -e "${GREEN}✓ Kibana is healthy (${i}0s)${NC}"
      break
    fi
    echo -ne "${BLUE}\rWaiting: ${i}0s / 360s${NC}"
    sleep 10
  done
  echo ""

  if [ "$KIBANA_READY" = false ]; then
    echo -e "${RED}Kibana did not become healthy within 6 minutes${NC}"
    echo -e "${YELLOW}Check logs with: podman logs k8s_vault_kibana${NC}"
    exit 1
  fi

  # Wait for Fleet Server to be ready (up to 2 minutes)
  echo -e "${BLUE}Waiting for Fleet Server to become ready...${NC}"
  FLEET_READY=false
  for i in {1..24}; do
    if podman exec k8s_vault_fleet_server curl -s http://localhost:8220/api/status >/dev/null 2>&1; then
      FLEET_READY=true
      echo -e "${GREEN}✓ Fleet Server is ready (${i}5s)${NC}"
      break
    fi
    echo -ne "${BLUE}\rWaiting: ${i}5s / 120s${NC}"
    sleep 5
  done
  echo ""

  if [ "$FLEET_READY" = false ]; then
    echo -e "${YELLOW}Fleet Server may not be fully ready yet${NC}"
    echo -e "${YELLOW}It should be ready shortly. Check with: podman logs k8s_vault_fleet_server${NC}"
  fi

  # Enrol Elastic Agent with Fleet
  echo ""
  echo -e "${BLUE}Enrolling Elastic Agent with Fleet...${NC}"
  if ./scripts/elk/fleet/20_post-deploy-fleet.sh; then
    echo -e "${GREEN}✓ Elastic Agent enrolled successfully${NC}"
  else
    echo -e "${YELLOW}⚠️  Elastic Agent enrollment failed or may need manual intervention${NC}"
    echo -e "${YELLOW}   Run: ./scripts/elk/fleet/20_post-deploy-fleet.sh${NC}"
  fi

  echo ""
  echo -e "${GREEN}=== Full Stack Deployed Successfully! ===${NC}"
  echo ""
  echo -e "${YELLOW}Next steps:${NC}"
  echo -e "  1. ${BLUE}task init${NC}        - Initialise Vault"
  echo -e "  2. ${BLUE}task unseal${NC}      - Unseal Vault"
  echo -e "  3. ${BLUE}task sample-data${NC} - Create sample data (optional, for testing)"
  echo -e "  4. ${BLUE}task audit${NC}       - Configure audit logging & Fleet integration"
  echo ""
else
  echo ""
  echo -e "${RED}Failed to deploy ELK stack${NC}"
  echo -e "${YELLOW}Check logs with: task elk-logs${NC}"
  exit 1
fi

