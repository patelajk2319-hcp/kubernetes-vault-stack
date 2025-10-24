# Create Kubernetes namespace
resource "kubernetes_namespace" "vault_stack" {
  metadata {
    name = var.namespace
  }
}

# Generate TLS certificates
module "certificates" {
  source = "./modules/certificates"

  namespace      = var.namespace
  common_name    = var.cert_common_name
  validity_hours = var.cert_validity_hours

  depends_on = [kubernetes_namespace.vault_stack]
}

# Create Kubernetes secrets
module "kubernetes_secrets" {
  source = "./modules/kubernetes/secrets"

  namespace      = var.namespace
  vault_cert_pem = module.certificates.vault_cert_pem
  vault_key_pem  = module.certificates.vault_key_pem
  ca_cert_pem    = module.certificates.ca_cert_pem
  vault_license  = local.vault_license

  depends_on = [kubernetes_namespace.vault_stack]
}

# Deploy Helm releases
module "helm_releases" {
  source = "./modules/helm-releases"

  namespace         = var.namespace
  vault_license_b64 = local.vault_license_b64

  depends_on = [
    kubernetes_namespace.vault_stack,
    module.kubernetes_secrets
  ]
}

# Create .env file
resource "null_resource" "env_file" {
  triggers = {
    vault_license = local.vault_license
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/create-env-file.sh '${local.vault_license}' '${path.module}/../.env'"
  }
}

# Create Kubernetes Services for external access
module "kubernetes_services" {
  source = "./modules/kubernetes/services"

  namespace = var.namespace

  depends_on = [module.helm_releases]
}

# Configure Vault for VSO (Vault Secrets Operator)
# This module is optional and can be applied after Vault is initialised and unsealed
# Run: terraform apply -target=module.vault_vso_config
module "vault_vso_config" {
  source = "./modules/vault-vso-config"

  kubernetes_host      = "https://kubernetes.default.svc.cluster.local"
  kubernetes_namespace = var.namespace
  vso_service_accounts = ["default", "vault-secrets-operator-controller-manager"]
  disable_local_ca_jwt = false

  # This module requires Vault to be initialised and unsealed
  # It will fail if run during initial deployment
  # Use: terraform apply -target=module.vault_vso_config
  depends_on = [module.helm_releases]
}
