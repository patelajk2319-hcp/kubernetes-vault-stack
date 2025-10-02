resource "kubernetes_secret" "vault_certs" {
  metadata {
    name      = "vault-certs"
    namespace = var.namespace
  }

  data = {
    "vault.crt" = var.vault_cert_pem
    "vault.key" = var.vault_key_pem
    "ca.crt"    = var.ca_cert_pem
  }

  type = "Opaque"
}

resource "kubernetes_secret" "elasticsearch_certs" {
  metadata {
    name      = "elasticsearch-certs"
    namespace = var.namespace
  }

  data = {
    "tls.crt" = var.vault_cert_pem
    "tls.key" = var.vault_key_pem
    "ca.crt"  = var.ca_cert_pem
  }

  type = "kubernetes.io/tls"
}

resource "kubernetes_secret" "vault_license" {
  metadata {
    name      = "vault-license"
    namespace = var.namespace
  }

  data = {
    "license" = var.vault_license_b64
  }

  type = "Opaque"
}
