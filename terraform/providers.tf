terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubectl" {
  config_path = "~/.kube/config"
}

provider "vault" {
  # Vault address - defaults to http://localhost:8200
  # Override with VAULT_ADDR environment variable
  address = "http://localhost:8200"

  # Skip TLS verification for local development
  # Set to false in production with proper TLS certificates
  skip_tls_verify = true

  # Token authentication - set VAULT_TOKEN environment variable
  # The token should have permissions to:
  # - Enable and configure auth methods
  # - Create and manage policies
  # - Create and manage secrets engines
  # - Create auth roles

  # Note: This provider is only used for the vault_vso_config module
  # which should be applied AFTER Vault is initialised and unsealed
}
