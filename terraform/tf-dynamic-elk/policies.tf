# ============================================================================
# Vault Policy for Dynamic Credentials
# ============================================================================

# Create policy document for reading dynamic credentials
data "vault_policy_document" "elasticsearch_dynamic" {
  rule {
    path         = "${vault_mount.database.path}/creds/${vault_database_secret_backend_role.elasticsearch.name}"
    capabilities = ["read"]
    description  = "Allow reading dynamic Elasticsearch credentials"
  }

  rule {
    path         = "${vault_mount.database.path}/creds/*"
    capabilities = ["list"]
    description  = "Allow listing database credential paths"
  }
}
