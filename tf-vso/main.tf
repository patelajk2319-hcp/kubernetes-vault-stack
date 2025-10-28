
# Enable KV v2 secrets engine at kvv2/
resource "vault_mount" "kvv2" {
  path = "kvv2"
  type = "kv"
  options = {
    version = "2"
  }
  description = "KV v2 secrets engine for VSO demo"
}

# Create webapp secret
resource "vault_kv_secret_v2" "webapp_config" {
  mount = vault_mount.kvv2.path
  name  = "webapp/config"

  data_json = jsonencode({
    username = var.webapp_username
    password = var.webapp_password
  })

  depends_on = [vault_mount.kvv2]
}

# Create Elasticsearch secret
resource "vault_kv_secret_v2" "elasticsearch_config" {
  mount = vault_mount.kvv2.path
  name  = "elasticsearch/config"

  data_json = jsonencode({
    es_host     = var.elasticsearch_host
    es_port     = var.elasticsearch_port
    es_protocol = var.elasticsearch_protocol
    es_username = var.elasticsearch_username
    es_password = var.elasticsearch_password
    es_index    = var.elasticsearch_index
    es_url      = "${var.elasticsearch_protocol}://${var.elasticsearch_host}:${var.elasticsearch_port}"
  })

  depends_on = [vault_mount.kvv2]
}

# Enable Kubernetes authentication method
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

# Configure Kubernetes authentication
resource "vault_kubernetes_auth_backend_config" "config" {
  backend            = vault_auth_backend.kubernetes.path
  kubernetes_host    = "https://kubernetes.default.svc.cluster.local"
  disable_iss_validation = true
}

# Create VSO policy document
data "vault_policy_document" "vso_policy" {
  rule {
    path         = "kvv2/data/webapp/*"
    capabilities = ["read"]
    description  = "Allow reading secrets from kvv2/webapp/*"
  }

  rule {
    path         = "kvv2/data/elasticsearch/*"
    capabilities = ["read"]
    description  = "Allow reading secrets from kvv2/elasticsearch/*"
  }

  rule {
    path         = "kvv2/metadata/*"
    capabilities = ["list"]
    description  = "Allow listing secrets"
  }
}

# Create VSO policy
resource "vault_policy" "vso_policy" {
  name   = "vso-policy"
  policy = data.vault_policy_document.vso_policy.hcl
}

# Create Kubernetes auth role for VSO
resource "vault_kubernetes_auth_backend_role" "vso_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "vso-role"
  bound_service_account_names      = ["default", "vault-secrets-operator-controller-manager"]
  bound_service_account_namespaces = [var.namespace]
  token_policies                   = [vault_policy.vso_policy.name]
  token_ttl                        = 3600
  audience                         = "vault"

  depends_on = [vault_kubernetes_auth_backend_config.config]
}

# ============================================================================
# Kubernetes Resources for VSO
# ============================================================================

# VaultConnection - defines how to connect to Vault
resource "kubectl_manifest" "vault_connection" {
  yaml_body = <<YAML
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultConnection
metadata:
  name: vault-connection
  namespace: ${var.namespace}
spec:
  address: http://${var.vault_service_name}:8200
  skipTLSVerify: true
YAML

  depends_on = [vault_kubernetes_auth_backend_role.vso_role]
}

# VaultAuth - defines how VSO authenticates to Vault
resource "kubectl_manifest" "vault_auth" {
  yaml_body = <<YAML
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: vault-auth
  namespace: ${var.namespace}
spec:
  vaultConnectionRef: vault-connection
  method: kubernetes
  mount: kubernetes
  kubernetes:
    role: vso-role
    serviceAccount: default
    audiences:
      - vault
YAML

  depends_on = [kubectl_manifest.vault_connection]
}

# VaultStaticSecret - syncs webapp secret from Vault to K8s
resource "kubectl_manifest" "webapp_secret" {
  yaml_body = <<YAML
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: webapp-secret
  namespace: ${var.namespace}
spec:
  vaultAuthRef: vault-auth
  mount: kvv2
  type: kv-v2
  path: webapp/config
  destination:
    name: webapp-secret
    create: true
  refreshAfter: 30s
  rolloutRestartTargets:
    - kind: Deployment
      name: webapp-deployment
YAML

  depends_on = [kubectl_manifest.vault_auth]
}

# VaultStaticSecret - syncs Elasticsearch secret from Vault to K8s
resource "kubectl_manifest" "elasticsearch_secret" {
  yaml_body = <<YAML
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: elasticsearch-secret
  namespace: ${var.namespace}
spec:
  vaultAuthRef: vault-auth
  mount: kvv2
  type: kv-v2
  path: elasticsearch/config
  destination:
    name: elasticsearch-secret
    create: true
  refreshAfter: 30s
  rolloutRestartTargets:
    - kind: Deployment
      name: webapp-deployment
YAML

  depends_on = [kubectl_manifest.vault_auth]
}

# Deploy webapp demonstration application
resource "kubectl_manifest" "webapp_deployment" {
  yaml_body = file("${path.module}/../k8s/vso-demo/05-webapp-deployment-simple.yaml")

  depends_on = [
    kubectl_manifest.webapp_secret,
    kubectl_manifest.elasticsearch_secret
  ]
}
