#!/bin/bash

# Pre-deployment checks - verify required tools are installed

# Source centralised colour configuration
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

# Check if kubectl can connect to cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
  # Check if we're using Minikube
  if command -v minikube >/dev/null 2>&1; then
    echo -e "${YELLOW}Cannot connect to Kubernetes cluster. Attempting to start Minikube...${NC}"

    # Try to start Minikube (idempotent - will start if stopped, or return success if already running)
    if minikube start; then
      echo -e "${GREEN}✓ Minikube started successfully${NC}"

      # Wait for cluster to be ready
      echo -e "${BLUE}Waiting for cluster to be ready...${NC}"
      kubectl wait --for=condition=Ready nodes --all --timeout=90s
      echo -e "${GREEN}✓ Cluster is ready${NC}"
    else
      echo -e "${RED}Failed to start Minikube${NC}"
      echo -e "${YELLOW}Try running 'minikube start' manually to see the error${NC}"
      exit 1
    fi
  else
    echo -e "${RED}Cannot connect to Kubernetes cluster${NC}"
    echo -e "${YELLOW}Please ensure your cluster is running and kubectl is configured correctly${NC}"
    exit 1
  fi
fi

# Check for Vault Enterprise licence file
LICENSE_FILE="licenses/vault-enterprise/license.lic"
if [ ! -f "$LICENSE_FILE" ]; then
  echo -e "${RED}Error: Vault licence file not found${NC}"
  echo -e "${YELLOW}Please create the licence file and add your Vault Enterprise licence:${NC}"
  echo "  1. Copy the example: cp licenses/vault-enterprise/license.lic.example licenses/vault-enterprise/license.lic"
  echo "  2. Edit licenses/vault-enterprise/license.lic and add your actual licence key"
  exit 1
fi

echo -e "${GREEN}All prerequisites met${NC}"