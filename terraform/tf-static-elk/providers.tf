terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.5"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "vault" {
  # Configuration from environment variables:
  # VAULT_ADDR - Vault server address
  # VAULT_TOKEN - Vault authentication token
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}
