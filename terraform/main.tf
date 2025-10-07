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
