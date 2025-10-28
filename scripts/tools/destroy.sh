#!/bin/bash

# Clean/destroy the entire stack using Terraform

# Source centralised colour configuration
source "$(dirname "$0")/../lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"

# Remove dynamic ELK credentials resources if they exist (before stopping port-forwards)
# This must be done while Vault is still accessible
echo -e "${BLUE}Checking for dynamic ELK credentials resources...${NC}"
cd "$(dirname "$0")/../.."
if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  if kubectl get vaultdynamicsecret -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo -e "${YELLOW}Found dynamic ELK credentials resources, removing via Terraform...${NC}"
    cd tf-dynamic-elk
    if [ -f "terraform.tfstate" ] || [ -f "terraform.tfstate.backup" ]; then
      terraform init -upgrade > /dev/null 2>&1 || true
      source ../.env 2>/dev/null || true
      terraform destroy -auto-approve 2>/dev/null || true
      rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
      rm -rf .terraform/
      echo -e "${GREEN}✓ Dynamic ELK credentials resources removed${NC}"
    else
      echo -e "${GREEN}✓ No dynamic ELK Terraform state found${NC}"
    fi
    cd ..
  else
    echo -e "${GREEN}✓ No dynamic ELK credentials resources found${NC}"
  fi
fi

# Remove VSO demo resources if they exist (before stopping port-forwards)
# This must be done while Vault is still accessible
echo -e "${BLUE}Checking for VSO demo resources...${NC}"
if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  if kubectl get vaultstaticsecret -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo -e "${YELLOW}Found VSO demo resources, removing via Terraform...${NC}"
    cd tf-vso
    if [ -f "terraform.tfstate" ] || [ -f "terraform.tfstate.backup" ]; then
      terraform init -upgrade > /dev/null 2>&1 || true
      source ../.env 2>/dev/null || true
      terraform destroy -auto-approve 2>/dev/null || true
      rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
      rm -rf .terraform/
      echo -e "${GREEN}✓ VSO demo resources removed${NC}"
    else
      echo -e "${GREEN}✓ No VSO Terraform state found${NC}"
    fi
    cd ..
  else
    echo -e "${GREEN}✓ No VSO demo resources found${NC}"
  fi
else
  echo -e "${GREEN}✓ Namespace does not exist${NC}"
fi

# Stop port-forwards (after VSO cleanup but before Terraform destroy)
echo -e "${BLUE}Stopping port-forwards...${NC}"
pkill -f "port-forward.*${NAMESPACE}" 2>/dev/null || true

# Stop minikube mount
echo -e "${BLUE}Stopping minikube mount...${NC}"
pkill -f "minikube mount" 2>/dev/null || true
echo -e "${GREEN}✓ Minikube mount stopped${NC}"

# Destroy ELK stack (podman) if it exists
echo -e "${BLUE}Checking for ELK stack (podman)...${NC}"
cd "$(dirname "$0")/../.."
if podman ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^k8s_vault_"; then
  echo -e "${YELLOW}Found ELK stack containers, destroying...${NC}"
  podman-compose -f elk-compose.yml down -v 2>/dev/null || true
  echo -e "${GREEN}✓ ELK stack destroyed${NC}"
else
  echo -e "${GREEN}✓ No ELK stack containers found${NC}"
fi

# Run Terraform destroy
echo -e "${YELLOW}Running Terraform Destroy...${NC}"
cd "$(dirname "$0")/../../tf-core"

# Check if state file exists (indicates resources were deployed)
if [ ! -f "terraform.tfstate" ] && [ ! -f "terraform.tfstate.backup" ]; then
  echo -e "${YELLOW}No Terraform state found - nothing to destroy${NC}"

  # Clean up any leftover Terraform files
  if [ -d ".terraform" ] || [ -f ".terraform.lock.hcl" ]; then
    echo -e "${BLUE}Cleaning up Terraform initialisation files...${NC}"
    rm -rf .terraform/ .terraform.lock.hcl
    echo -e "${GREEN}Terraform files cleaned${NC}"
  fi

  cd ..

  # Remove vault-init.json if it exists
  if [ -f vault-init.json ]; then
    rm -f vault-init.json
    echo -e "${GREEN}Removed vault-init.json${NC}"
  fi

  # Remove vault audit logs directory
  if [ -d vault-audit-logs ]; then
    rm -rf vault-audit-logs
    echo -e "${GREEN}Removed vault-audit-logs/${NC}"
  fi

  # Remove fleet tokens directory
  if [ -d fleet-tokens ]; then
    rm -rf fleet-tokens
    echo -e "${GREEN}Removed fleet-tokens/${NC}"
  fi

  # Remove certificates directory
  if [ -d certs ]; then
    rm -rf certs
    echo -e "${GREEN}Removed certs/${NC}"
  fi

  echo -e "${GREEN}Stack already destroyed${NC}"
  exit 0
fi

# Initialise Terraform (in case modules were updated)
echo -e "${BLUE}Initialising Terraform...${NC}"
terraform init -upgrade > /dev/null 2>&1

# Run destroy (don't use set -e to allow cleanup even if destroy fails)
if terraform destroy -auto-approve; then
  # Clean up Terraform state files only if destroy succeeded
  echo -e "${BLUE}Cleaning up Terraform state files...${NC}"
  rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
  rm -rf .terraform/
  echo -e "${GREEN}Terraform state files removed${NC}"
else
  echo -e "${YELLOW}Terraform destroy failed!${NC}"
  exit 1
fi

# Remove runtime directories and files
cd ..
if [ -f vault-init.json ]; then
  rm -f vault-init.json
  echo -e "${GREEN}Removed vault-init.json${NC}"
fi

# Remove fleet tokens directory
if [ -d fleet-tokens ]; then
  rm -rf fleet-tokens
  echo -e "${GREEN}Removed fleet-tokens/${NC}"
fi

# Remove certificates directory
if [ -d certs ]; then
  rm -rf certs
  echo -e "${GREEN}Removed certs/${NC}"
fi

# Remove vault audit logs directory
if [ -d vault-audit-logs ]; then
  rm -rf vault-audit-logs
  echo -e "${GREEN}Removed vault-audit-logs/${NC}"
fi

echo -e "${GREEN}Stack destroyed${NC}"
