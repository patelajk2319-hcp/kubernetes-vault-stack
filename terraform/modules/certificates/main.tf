# Generate private key for CA
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate self-signed CA certificate
resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "vault-ca"
    organization = "HashiCorp"
  }

  validity_period_hours = var.validity_hours
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "digital_signature",
  ]
}

# Generate private key for Vault server
resource "tls_private_key" "vault" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate certificate signing request
resource "tls_cert_request" "vault" {
  private_key_pem = tls_private_key.vault.private_key_pem

  subject {
    common_name  = var.common_name
    organization = "HashiCorp"
  }

  dns_names = [
    "vault",
    "vault.${var.namespace}",
    "vault.${var.namespace}.svc",
    "vault.${var.namespace}.svc.cluster.local",
    "*.vault-internal",
    "*.vault-internal.${var.namespace}",
    "*.vault-internal.${var.namespace}.svc",
    "*.vault-internal.${var.namespace}.svc.cluster.local",
  ]

  ip_addresses = [
    "127.0.0.1",
  ]
}

# Sign the certificate with CA
resource "tls_locally_signed_cert" "vault" {
  cert_request_pem   = tls_cert_request.vault.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = var.validity_hours

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}
