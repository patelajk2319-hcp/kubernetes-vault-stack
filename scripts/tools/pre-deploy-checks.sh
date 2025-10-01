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

echo -e "${GREEN}All prerequisites met${NC}"