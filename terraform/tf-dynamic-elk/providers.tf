terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.5"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# Vault provider configuration
# Requires VAULT_ADDR and VAULT_TOKEN environment variables to be set
provider "vault" {
  # Address and token are read from environment variables:
  # - VAULT_ADDR (e.g., http://localhost:8200)
  # - VAULT_TOKEN (from .env file)
}

# Kubernetes provider for managing Kubernetes resources
provider "kubernetes" {
  config_path = "~/.kube/config"
}
