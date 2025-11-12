# Certificate Authority (CA)
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = var.cert_key_size
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name         = "Elastic-Certificate-Authority"
    organization        = "Elastic"
    organizational_unit = "IT"
    street_address      = []
    locality            = "San Francisco"
    province            = "CA"
    country             = "US"
  }

  validity_period_hours = var.cert_validity_days * 24
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "digital_signature",
  ]
}

# Elasticsearch Certificate
resource "tls_private_key" "elasticsearch" {
  algorithm = "RSA"
  rsa_bits  = var.cert_key_size
}

resource "tls_cert_request" "elasticsearch" {
  private_key_pem = tls_private_key.elasticsearch.private_key_pem

  subject {
    common_name         = "elasticsearch"
    organization        = "Elastic"
    organizational_unit = "IT"
    street_address      = []
    locality            = "San Francisco"
    province            = "CA"
    country             = "US"
  }

  dns_names = [
    "elasticsearch",
    "localhost",
  ]

  ip_addresses = [
    "127.0.0.1",
  ]
}

resource "tls_locally_signed_cert" "elasticsearch" {
  cert_request_pem   = tls_cert_request.elasticsearch.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = var.cert_validity_days * 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

# Kibana Certificate
resource "tls_private_key" "kibana" {
  algorithm = "RSA"
  rsa_bits  = var.cert_key_size
}

resource "tls_cert_request" "kibana" {
  private_key_pem = tls_private_key.kibana.private_key_pem

  subject {
    common_name         = "kibana"
    organization        = "Elastic"
    organizational_unit = "IT"
    street_address      = []
    locality            = "San Francisco"
    province            = "CA"
    country             = "US"
  }

  dns_names = [
    "kibana",
    "localhost",
  ]

  ip_addresses = [
    "127.0.0.1",
  ]
}

resource "tls_locally_signed_cert" "kibana" {
  cert_request_pem   = tls_cert_request.kibana.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = var.cert_validity_days * 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

# Fleet Server Certificate
resource "tls_private_key" "fleet_server" {
  algorithm = "RSA"
  rsa_bits  = var.cert_key_size
}

resource "tls_cert_request" "fleet_server" {
  private_key_pem = tls_private_key.fleet_server.private_key_pem

  subject {
    common_name         = "fleet-server"
    organization        = "Elastic"
    organizational_unit = "IT"
    street_address      = []
    locality            = "San Francisco"
    province            = "CA"
    country             = "US"
  }

  dns_names = [
    "fleet-server",
    "localhost",
  ]

  ip_addresses = [
    "127.0.0.1",
  ]
}

resource "tls_locally_signed_cert" "fleet_server" {
  cert_request_pem   = tls_cert_request.fleet_server.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = var.cert_validity_days * 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

# Write certificates to files
resource "local_file" "ca_cert" {
  content         = tls_self_signed_cert.ca.cert_pem
  filename        = "${var.cert_output_path}/ca/ca.crt"
  file_permission = "0644"
}

resource "local_file" "ca_key" {
  content         = tls_private_key.ca.private_key_pem
  filename        = "${var.cert_output_path}/ca/ca.key"
  file_permission = "0600"
}

resource "local_file" "elasticsearch_cert" {
  content         = tls_locally_signed_cert.elasticsearch.cert_pem
  filename        = "${var.cert_output_path}/elasticsearch/elasticsearch.crt"
  file_permission = "0644"
}

resource "local_file" "elasticsearch_key" {
  content         = tls_private_key.elasticsearch.private_key_pem
  filename        = "${var.cert_output_path}/elasticsearch/elasticsearch.key"
  file_permission = "0600"
}

resource "local_file" "kibana_cert" {
  content         = tls_locally_signed_cert.kibana.cert_pem
  filename        = "${var.cert_output_path}/kibana/kibana.crt"
  file_permission = "0644"
}

resource "local_file" "kibana_key" {
  content         = tls_private_key.kibana.private_key_pem
  filename        = "${var.cert_output_path}/kibana/kibana.key"
  file_permission = "0600"
}

resource "local_file" "fleet_server_cert" {
  content         = tls_locally_signed_cert.fleet_server.cert_pem
  filename        = "${var.cert_output_path}/fleet-server/fleet-server.crt"
  file_permission = "0644"
}

resource "local_file" "fleet_server_key" {
  content         = tls_private_key.fleet_server.private_key_pem
  filename        = "${var.cert_output_path}/fleet-server/fleet-server.key"
  file_permission = "0600"
}
