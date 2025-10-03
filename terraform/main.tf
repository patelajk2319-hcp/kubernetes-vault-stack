# Create Kubernetes namespace
resource "kubernetes_namespace" "vault_stack" {
  metadata {
    name = var.namespace
  }
}

# Read Vault license from file
locals {
  vault_license     = trimspace(file(var.vault_license_file))
  vault_license_b64 = base64encode(local.vault_license)
}

# Generate TLS certificates
module "certificates" {
  source = "./modules/certificates"

  namespace      = var.namespace
  common_name    = var.cert_common_name
  validity_hours = var.cert_validity_hours

  depends_on = [kubernetes_namespace.vault_stack]
}

# Create Kubernetes secrets for certificates only
# License secret is managed by Helm chart
resource "kubernetes_secret" "vault_certs" {
  metadata {
    name      = "vault-certs"
    namespace = var.namespace
  }

  data = {
    "vault.crt" = module.certificates.vault_cert_pem
    "vault.key" = module.certificates.vault_key_pem
    "ca.crt"    = module.certificates.ca_cert_pem
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.vault_stack]
}

resource "kubernetes_secret" "elasticsearch_certs" {
  metadata {
    name      = "elasticsearch-certs"
    namespace = var.namespace
  }

  data = {
    "tls.crt" = module.certificates.vault_cert_pem
    "tls.key" = module.certificates.vault_key_pem
    "ca.crt"  = module.certificates.ca_cert_pem
  }

  type = "kubernetes.io/tls"

  depends_on = [kubernetes_namespace.vault_stack]
}

resource "kubernetes_secret" "vault_license" {
  metadata {
    name      = "vault-license"
    namespace = var.namespace
  }

  data = {
    "license" = local.vault_license
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.vault_stack]
}

# Deploy Helm releases
module "helm_releases" {
  source = "./modules/helm-releases"

  namespace         = var.namespace
  vault_license_b64 = local.vault_license_b64

  depends_on = [
    kubernetes_namespace.vault_stack,
    kubernetes_secret.vault_certs,
    kubernetes_secret.elasticsearch_certs,
    kubernetes_secret.vault_license
  ]
}

# Create .env file
resource "local_file" "env_file" {
  filename = "${path.module}/../.env"
  content  = <<-EOT
    # Vault Configuration
    export VAULT_ADDR=http://127.0.0.1:8200

    # Vault Enterprise license - Read from licenses/vault-enterprise/license.lic
    export VAULT_LICENSE=${local.vault_license}

    # Vault root token - dynamically generated during 'task init'
    export VAULT_TOKEN=placeholder
  EOT

  file_permission = "0600"
}

# Create Kubernetes Services for external access (replaces port-forwarding)
resource "kubernetes_service" "vault_nodeport" {
  metadata {
    name      = "vault-nodeport"
    namespace = var.namespace
  }

  spec {
    type = "NodePort"

    selector = {
      "app.kubernetes.io/name"     = "vault"
      "app.kubernetes.io/instance" = "vault-stack"
    }

    port {
      name        = "http"
      port        = 8200
      target_port = 8200
      node_port   = 30200
    }

    port {
      name        = "https-internal"
      port        = 8201
      target_port = 8201
      node_port   = 30201
    }
  }

  depends_on = [module.helm_releases]
}

resource "kubernetes_service" "grafana_nodeport" {
  metadata {
    name      = "grafana-nodeport"
    namespace = var.namespace
  }

  spec {
    type = "NodePort"

    selector = {
      "app.kubernetes.io/name"     = "grafana"
      "app.kubernetes.io/instance" = "vault-stack-grafana"
    }

    port {
      name        = "http"
      port        = 3000
      target_port = 3000
      node_port   = 30300
    }
  }

  depends_on = [module.helm_releases]
}

resource "kubernetes_service" "prometheus_nodeport" {
  metadata {
    name      = "prometheus-nodeport"
    namespace = var.namespace
  }

  spec {
    type = "NodePort"

    selector = {
      "app.kubernetes.io/name"     = "prometheus"
      "app.kubernetes.io/instance" = "vault-stack-prometheus"
    }

    port {
      name        = "http"
      port        = 9090
      target_port = 9090
      node_port   = 30090
    }
  }

  depends_on = [module.helm_releases]
}

resource "kubernetes_service" "kibana_nodeport" {
  metadata {
    name      = "kibana-nodeport"
    namespace = var.namespace
  }

  spec {
    type = "NodePort"

    selector = {
      "kibana.k8s.elastic.co/name" = "kibana"
    }

    port {
      name        = "http"
      port        = 5601
      target_port = 5601
      node_port   = 30601
    }
  }

  depends_on = [module.helm_releases]
}

resource "kubernetes_service" "elasticsearch_nodeport" {
  metadata {
    name      = "elasticsearch-nodeport"
    namespace = var.namespace
  }

  spec {
    type = "NodePort"

    selector = {
      "elasticsearch.k8s.elastic.co/cluster-name" = "elasticsearch"
    }

    port {
      name        = "https"
      port        = 9200
      target_port = 9200
      node_port   = 30920
    }
  }

  depends_on = [module.helm_releases]
}
