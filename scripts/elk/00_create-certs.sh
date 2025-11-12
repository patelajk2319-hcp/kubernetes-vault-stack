#!/bin/bash
set -euo pipefail

# Generate TLS certificates for ELK stack using Terraform

# Source centralised colour configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"

echo -e "${BLUE}=== Generating ELK TLS Certificates with Terraform ===${NC}"
echo ""

# Navigate to project root
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

# Create certificate directory structure
echo -e "${BLUE}Creating certificate directory structure...${NC}"
mkdir -p certs/{ca,elasticsearch,kibana,fleet-server}
echo -e "${GREEN}✓ Certificate directories created${NC}"
echo ""

# Navigate to terraform directory
cd "$PROJECT_ROOT/terraform/tf-elk-certs"

# Initialise Terraform
echo -e "${BLUE}Initialising Terraform...${NC}"
terraform init -upgrade > /dev/null
echo -e "${GREEN}✓ Terraform initialised${NC}"
echo ""

# Generate certificates
echo -e "${BLUE}Generating certificates...${NC}"
terraform apply -auto-approve

echo ""
echo -e "${GREEN}=== Certificate Generation Completed ===${NC}"
echo ""
echo "Generated certificates:"
terraform output -json | jq -r 'to_entries | .[] | "  \(.key): \(.value.value)"'
echo ""
