#!/bin/bash

# Pre-deployment checks - verify required tools are installed

# Source centralized color configuration
source "$(dirname "$0")/../lib/colors.sh"

echo -e "${BLUE}Checking prerequisites...${NC}"
MISSING=""

command -v kubectl >/dev/null 2>&1 || MISSING="$MISSING kubectl"
command -v helm >/dev/null 2>&1 || MISSING="$MISSING helm"
command -v jq >/dev/null 2>&1 || MISSING="$MISSING jq"

if [ -n "$MISSING" ]; then
  echo -e "${YELLOW}Missing required tools:$MISSING${NC}"
  echo "Please install them and try again"
  exit 1
fi

kubectl cluster-info >/dev/null 2>&1 || {
  echo -e "${YELLOW}Cannot connect to Kubernetes cluster${NC}"
  exit 1
}

# Check for Vault Enterprise license file
LICENSE_FILE="licenses/vault-enterprise/license.lic"
if [ ! -f "$LICENSE_FILE" ]; then
  echo -e "${RED}Error: Vault license file not found${NC}"
  echo -e "${YELLOW}Please create the license file and add your Vault Enterprise license:${NC}"
  echo "  1. Copy the example: cp licenses/vault-enterprise/license.lic.example licenses/vault-enterprise/license.lic"
  echo "  2. Edit licenses/vault-enterprise/license.lic and add your actual license key"
  exit 1
fi

echo -e "${GREEN}All prerequisites met${NC}"