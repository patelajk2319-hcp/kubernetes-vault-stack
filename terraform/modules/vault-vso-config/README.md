# Vault VSO Configuration Module

This Terraform module configures HashiCorp Vault to work with the Vault Secrets Operator (VSO).

## What This Module Does

1. **Enables KV v2 Secrets Engine** at `kvv2/` path
2. **Creates Demo Secrets**:
   - `kvv2/webapp/config` - Web application credentials
   - `kvv2/database/config` - Database connection details
3. **Configures Kubernetes Authentication** method
4. **Creates VSO Policy** with appropriate read permissions
5. **Creates Kubernetes Auth Role** for VSO to authenticate

## Prerequisites

- Vault must be initialised and unsealed
- Vault Terraform provider must be configured with appropriate credentials
- Kubernetes cluster must be accessible

## Usage

```hcl
module "vault_vso_config" {
  source = "./modules/vault-vso-config"

  kubernetes_host      = "https://kubernetes.default.svc.cluster.local"
  kubernetes_namespace = "vault-stack"
  vso_service_accounts = ["default", "vault-secrets-operator-controller-manager"]
  disable_local_ca_jwt = false
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| kubernetes_host | Kubernetes API server address | `string` | `"https://kubernetes.default.svc.cluster.local"` | no |
| kubernetes_ca_cert | Kubernetes CA certificate | `string` | `""` | no |
| disable_local_ca_jwt | Disable local CA JWT verification | `bool` | `false` | no |
| kubernetes_namespace | Namespace where VSO runs | `string` | `"vault-stack"` | no |
| vso_service_accounts | Service accounts for VSO | `list(string)` | `["default", "vault-secrets-operator-controller-manager"]` | no |

## Outputs

| Name | Description |
|------|-------------|
| kvv2_mount_path | KV v2 mount path |
| kubernetes_auth_path | Kubernetes auth method path |
| vso_role_name | VSO Kubernetes auth role name |
| vso_policy_name | VSO policy name |
| webapp_secret_path | Path to webapp secret |
| database_secret_path | Path to database secret |

## Secrets Created

### webapp/config
```json
{
  "username": "static-user",
  "password": "static-password"
}
```

### database/config
```json
{
  "db_host": "postgres.vault-stack.svc.cluster.local",
  "db_port": "5432",
  "db_name": "myapp",
  "db_username": "dbadmin",
  "db_password": "sup3rS3cr3t!"
}
```

## Policy

The VSO policy grants:
- `read` access to `kvv2/data/webapp/*`
- `read` access to `kvv2/data/database/*`
- `list` access to `kvv2/metadata/*`
