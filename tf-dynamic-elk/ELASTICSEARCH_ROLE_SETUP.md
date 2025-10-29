# Elasticsearch Role Setup for Dynamic Credentials

## Overview

This module uses Vault's database secrets engine to generate dynamic, time-limited Elasticsearch credentials. To enable Kibana UI login, we assign both a custom role and the reserved `kibana_admin` role to dynamically created users.

## Custom Elasticsearch Role

The `vault_es_role` is a custom Elasticsearch role that must be created in Elasticsearch **before** applying this Terraform module. This role grants the necessary permissions for:

- **Index operations**: Read, write, create, delete, and monitor all indices
- **Cluster operations**: Monitor cluster health, manage index templates, view ML/Watcher/Transform jobs
- **Kibana application access**: Full access to Kibana application (`.kibana` indices)

## Creating the Custom Role

The custom role is created automatically during the initial ELK stack setup. If you need to recreate it manually, use the following command:

```bash
curl -k -u elastic:password123 -X POST "https://localhost:9200/_security/role/vault_es_role" \
  -H 'Content-Type: application/json' -d'
{
  "cluster": [
    "monitor",
    "manage_index_templates",
    "monitor_ml",
    "monitor_watcher",
    "monitor_transform"
  ],
  "indices": [
    {
      "names": [ "*" ],
      "privileges": [
        "read",
        "write",
        "create_index",
        "delete_index",
        "view_index_metadata",
        "monitor"
      ]
    }
  ],
  "applications": [
    {
      "application": "kibana-.kibana",
      "privileges": [ "all" ],
      "resources": [ "*" ]
    }
  ],
  "run_as": []
}'
```

## Role Assignment Strategy

### Why Two Roles?

Vault's Elasticsearch database plugin supports two mutually exclusive approaches for role assignment:

1. **`elasticsearch_role_definition`**: Define an inline custom role (permissions specified in Vault)
2. **`elasticsearch_roles`**: Assign pre-existing Elasticsearch roles (roles must exist in Elasticsearch)

We use approach #2 (`elasticsearch_roles`) because:
- Kibana UI login requires the reserved `kibana_admin` role
- We need custom ES permissions beyond what `kibana_admin` provides
- We cannot mix inline definitions with reserved role assignments

### Assigned Roles

Dynamic users are assigned **two roles**:

1. **`vault_es_role`** (custom role)
   - Custom Elasticsearch permissions for index/cluster operations
   - Created in Elasticsearch via REST API

2. **`kibana_admin`** (reserved role)
   - Pre-defined Elasticsearch role required for Kibana UI authentication
   - Provides necessary Kibana management permissions

## Verification

After dynamic credentials are generated, verify the user has both roles:

```bash
# Generate credentials
vault read database/creds/elasticsearch-role

# Check user roles in Elasticsearch (replace USERNAME with generated username)
curl -k -u elastic:password123 \
  "https://localhost:9200/_security/user/USERNAME" | jq '.USERNAME.roles'
```

Expected output:
```json
[
  "vault_es_role",
  "kibana_admin"
]
```

## Testing Kibana Login

Test Kibana API access with dynamic credentials:

```bash
# Use credentials from vault read command
curl -k -u "USERNAME:PASSWORD" \
  "https://localhost:5601/api/status" | jq '.status.overall'
```

Expected response:
```json
{
  "level": "available",
  "summary": "All services and plugins are available"
}
```

## Credential Lifecycle

- **Default TTL**: 5 minutes
- **Max TTL**: 5 minutes
- **Lease Renewal**: Every 60 seconds (same credentials)
- **Rotation**: New credentials generated when max TTL reached
- **Revocation**: Old credentials automatically revoked after rotation

## References

- [Vault Database Secrets Engine - Elasticsearch](https://developer.hashicorp.com/vault/docs/secrets/databases/elasticdb)
- [Elasticsearch Security API - Create Role](https://www.elastic.co/guide/en/elasticsearch/reference/current/security-api-put-role.html)
- [Kibana Built-in Roles](https://www.elastic.co/guide/en/kibana/current/kibana-role-management.html)
