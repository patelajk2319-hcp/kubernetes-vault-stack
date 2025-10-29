#!/bin/bash

# Clean/destroy the entire stack using Terraform

# Source centralised colour configuration
source "$(dirname "$0")/../lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo -e "${BLUE}=== Destroying Vault Stack ===${NC}"
echo ""

# ============================================================================
# Destroy Terraform-managed resources (in reverse dependency order)
# ============================================================================

cd "$PROJECT_ROOT"

# 1. Destroy dynamic ELK credentials demo
if [ -f "tf-dynamic-elk/terraform.tfstate" ]; then
  echo -e "${BLUE}Destroying dynamic ELK credentials...${NC}"
  cd tf-dynamic-elk

  # Source Vault credentials
  source ../.env 2>/dev/null || true

  # Force disable database mount to bypass lease revocation issues
  if [ -n "$VAULT_ADDR" ] && [ -n "$VAULT_TOKEN" ]; then
    echo -e "${YELLOW}Force disabling database mount (bypassing lease revocation)...${NC}"
    vault secrets disable database 2>/dev/null || true
    echo -e "${GREEN}✓ Database mount disabled${NC}"
  fi

  echo -e "${YELLOW}Initialising Terraform...${NC}"
  terraform init -upgrade

  # Remove database mount from state since we manually disabled it
  echo -e "${YELLOW}Removing database mount from Terraform state...${NC}"
  terraform state rm vault_mount.database 2>/dev/null || true

  echo -e "${YELLOW}Running terraform destroy...${NC}"
  if terraform destroy -auto-approve; then
    echo -e "${GREEN}✓ Dynamic ELK credentials destroyed${NC}"
  else
    echo -e "${RED}✗ Failed to destroy dynamic ELK credentials${NC}"
    exit 1
  fi
  cd "$PROJECT_ROOT"
fi

# 2. Destroy static ELK secrets demo
if [ -f "tf-static-elk/terraform.tfstate" ]; then
  echo -e "${BLUE}Destroying static ELK secrets...${NC}"
  cd tf-static-elk
  echo -e "${YELLOW}Initialising Terraform...${NC}"
  terraform init -upgrade
  source ../.env 2>/dev/null || true
  echo -e "${YELLOW}Running terraform destroy...${NC}"
  if terraform destroy -auto-approve; then
    echo -e "${GREEN}✓ Static ELK secrets destroyed${NC}"
  else
    echo -e "${RED}✗ Failed to destroy static ELK secrets${NC}"
    exit 1
  fi
  cd "$PROJECT_ROOT"
fi

# 3. Destroy VSO infrastructure
if [ -f "tf-vso/terraform.tfstate" ]; then
  echo -e "${BLUE}Destroying VSO infrastructure...${NC}"
  cd tf-vso
  echo -e "${YELLOW}Initialising Terraform...${NC}"
  terraform init -upgrade
  source ../.env 2>/dev/null || true
  echo -e "${YELLOW}Running terraform destroy...${NC}"
  if terraform destroy -auto-approve; then
    echo -e "${GREEN}✓ VSO infrastructure destroyed${NC}"
  else
    echo -e "${RED}✗ Failed to destroy VSO infrastructure${NC}"
    exit 1
  fi
  cd "$PROJECT_ROOT"
fi

echo ""

# ============================================================================
# Clean up processes
# ============================================================================

echo -e "${BLUE}Stopping port-forwards...${NC}"
pkill -f "port-forward.*${NAMESPACE}" 2>/dev/null || true
echo -e "${GREEN}✓ Port-forwards stopped${NC}"

echo -e "${BLUE}Stopping minikube mount...${NC}"
pkill -f "minikube mount" 2>/dev/null || true
echo -e "${GREEN}✓ Minikube mount stopped${NC}"

echo ""

# ============================================================================
# Destroy ELK stack (Podman containers)
# ============================================================================

echo -e "${BLUE}Destroying ELK stack (Podman)...${NC}"
if podman ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^k8s_vault_"; then
  podman-compose -f elk-compose.yml down -v 2>/dev/null || true
  echo -e "${GREEN}✓ ELK stack destroyed${NC}"
else
  echo -e "${YELLOW}ELK stack not running, skipping${NC}"
fi

echo ""

# ============================================================================
# Force remove stuck VSO resources (prevents namespace from hanging)
# ============================================================================

if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  echo -e "${BLUE}Checking for stuck VSO resources...${NC}"

  # Remove VaultStaticSecret finalizers
  if kubectl get vaultstaticsecret -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo -e "${YELLOW}Removing finalizers from VaultStaticSecret resources...${NC}"
    kubectl get vaultstaticsecret -n "${NAMESPACE}" -o name 2>/dev/null | \
      xargs -I {} kubectl patch {} -n "${NAMESPACE}" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    echo -e "${GREEN}✓ VaultStaticSecret finalizers removed${NC}"
  fi

  # Remove VaultDynamicSecret finalizers
  if kubectl get vaultdynamicsecret -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo -e "${YELLOW}Removing finalizers from VaultDynamicSecret resources...${NC}"
    kubectl get vaultdynamicsecret -n "${NAMESPACE}" -o name 2>/dev/null | \
      xargs -I {} kubectl patch {} -n "${NAMESPACE}" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    echo -e "${GREEN}✓ VaultDynamicSecret finalizers removed${NC}"
  fi

  # Remove VaultAuth finalizers
  if kubectl get vaultauth -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo -e "${YELLOW}Removing finalizers from VaultAuth resources...${NC}"
    kubectl get vaultauth -n "${NAMESPACE}" -o name 2>/dev/null | \
      xargs -I {} kubectl patch {} -n "${NAMESPACE}" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    echo -e "${GREEN}✓ VaultAuth finalizers removed${NC}"
  fi

  # Remove VaultConnection finalizers
  if kubectl get vaultconnection -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo -e "${YELLOW}Removing finalizers from VaultConnection resources...${NC}"
    kubectl get vaultconnection -n "${NAMESPACE}" -o name 2>/dev/null | \
      xargs -I {} kubectl patch {} -n "${NAMESPACE}" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    echo -e "${GREEN}✓ VaultConnection finalizers removed${NC}"
  fi
fi

echo ""

# ============================================================================
# Destroy core infrastructure (Vault, K8s namespace, all Helm releases)
# ============================================================================

echo -e "${BLUE}Destroying core infrastructure...${NC}"
cd "$PROJECT_ROOT/tf-core"
if [ -f "terraform.tfstate" ]; then
  echo -e "${YELLOW}Initialising Terraform...${NC}"
  terraform init -upgrade
  echo -e "${YELLOW}Running terraform destroy (this may take several minutes)...${NC}"
  if terraform destroy -auto-approve; then
    echo -e "${GREEN}✓ Core infrastructure destroyed${NC}"
  else
    echo -e "${RED}✗ Failed to destroy core infrastructure${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}No state file, skipping${NC}"
fi

cd "$PROJECT_ROOT"

echo ""

# ============================================================================
# Clean up Terraform state files (all modules in one operation)
# ============================================================================

echo -e "${BLUE}Cleaning up Terraform state files...${NC}"
find tf-core tf-vso tf-static-elk tf-dynamic-elk -type f \( -name "terraform.tfstate*" -o -name ".terraform.lock.hcl" \) -delete 2>/dev/null
find tf-core tf-vso tf-static-elk tf-dynamic-elk -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null
echo -e "${GREEN}✓ Terraform state files removed${NC}"

echo ""

# ============================================================================
# Clean up local files and directories
# ============================================================================

echo -e "${BLUE}Cleaning up local files...${NC}"

[ -f vault-init.json ] && rm -f vault-init.json && echo -e "${GREEN}Removed vault-init.json${NC}"
[ -f .env ] && rm -f .env && echo -e "${GREEN}Removed .env${NC}"

[ -d vault-audit-logs ] && rm -rf vault-audit-logs && echo -e "${GREEN}Removed vault-audit-logs/${NC}"
[ -d fleet-tokens ] && rm -rf fleet-tokens && echo -e "${GREEN}Removed fleet-tokens/${NC}"
[ -d certs ] && rm -rf certs && echo -e "${GREEN}Removed certs/${NC}"

echo ""
echo -e "${GREEN}=== Stack Destroyed ===${NC}"
echo -e "${YELLOW}Note: Minikube cluster remains running${NC}"
