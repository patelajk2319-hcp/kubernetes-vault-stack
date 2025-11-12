#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

NAMESPACE="${NAMESPACE:-vault-stack}"

echo -e "\033[0;34m=== Deploying Static Secrets Demo ===\033[0m"
echo ""

# Load Vault environment variables
echo -e "\033[0;34mLoading Vault environment variables...\033[0m"
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo -e "\033[0;31mError: .env file not found. Run 'task init' first.\033[0m"
    exit 1
fi
source "$PROJECT_ROOT/.env"

# Check VSO prerequisites
echo -e "\033[0;34mChecking VSO prerequisites...\033[0m"
if ! kubectl get deployment vault-secrets-operator-controller-manager -n "$NAMESPACE" &>/dev/null; then
    echo -e "\033[0;31mError: Vault Secrets Operator not found. Run 'task vso' first.\033[0m"
    exit 1
fi

# Navigate to tf-static-elk directory
cd "$PROJECT_ROOT/terraform/tf-static-elk"

# Initialize Terraform
echo -e "\033[0;34mInitialising Terraform...\033[0m"
terraform init -upgrade > /dev/null

# Apply Terraform configuration
echo -e "\033[0;34mApplying Terraform configuration...\033[0m"
terraform apply -auto-approve

echo ""
echo -e "\033[0;32m=== Static Secrets Demo Deployed Successfully! ===\033[0m"
echo ""
echo -e "\033[0;34mStatic secrets are synchronised from Vault via VSO.\033[0m"
echo -e "\033[0;34mSecrets are checked every 30 seconds for updates.\033[0m"
echo ""
