# ============================================================================
# Vault Policies for Static Secrets
# ============================================================================

# VSO Policy Document
# Defines what secrets VSO can access in Vault for static secrets
#
# This policy grants:
# - Read access to kvv2/data/webapp/* (webapp configuration)
# - Read access to kvv2/data/elasticsearch/* (Elasticsearch configuration)
# - List access to kvv2/metadata/* (for browsing/discovery)
#
# Policy path format for KV v2:
# - Data: kvv2/data/<path> (actual secret values)
# - Metadata: kvv2/metadata/<path> (versions, created time, etc.)
data "vault_policy_document" "static_secrets_policy" {
  rule {
    path         = "kvv2/data/webapp/*"
    capabilities = ["read"]
    description  = "Allow reading webapp secrets from KV v2"
  }

  rule {
    path         = "kvv2/data/elasticsearch/*"
    capabilities = ["read"]
    description  = "Allow reading Elasticsearch secrets from KV v2"
  }

  rule {
    path         = "kvv2/metadata/*"
    capabilities = ["list"]
    description  = "Allow listing all secrets for discovery"
  }
}
