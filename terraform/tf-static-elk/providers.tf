terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.4"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
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
