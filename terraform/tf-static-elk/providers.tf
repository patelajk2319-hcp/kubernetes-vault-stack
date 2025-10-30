terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.5"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

provider "vault" {
  # Configuration from environment variables:
  # VAULT_ADDR - Vault server address
  # VAULT_TOKEN - Vault authentication token
}

provider "kubectl" {
  config_path = "~/.kube/config"
}
