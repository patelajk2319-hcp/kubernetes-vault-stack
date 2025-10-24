# Vault Secrets Operator (VSO) Demo

This demo demonstrates how to use HashiCorp's Vault Secrets Operator to synchronise secrets from Vault to Kubernetes native secrets.

## Overview

The Vault Secrets Operator (VSO) allows Kubernetes pods to consume Vault secrets natively through Kubernetes secrets, without requiring Vault agent sidecars or init containers. VSO continuously monitors Vault secrets and automatically updates Kubernetes secrets when changes occur.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Kubernetes Cluster                       │
│                                                                  │
│  ┌──────────────┐      ┌──────────────────┐                    │
│  │   Vault Pod  │◄─────┤  VSO Operator    │                    │
│  │              │      │  Controller      │                    │
│  └──────────────┘      └────────┬─────────┘                    │
│         ▲                        │                               │
│         │                        ▼                               │
│  ┌──────┴───────┐      ┌──────────────────┐                    │
│  │  KV Secrets  │      │   K8s Secrets    │                    │
│  │  kvv2/       │      │  - webapp-secret │                    │
│  │  - webapp    │      │  - database-secret│                   │
│  │  - database  │      └────────┬─────────┘                    │
│  └──────────────┘               │                               │
│                                  ▼                               │
│                        ┌──────────────────┐                    │
│                        │  Demo Web App    │                    │
│                        │  (nginx)         │                    │
│                        └──────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

## What's Included

### Terraform Modules

1. **VSO Helm Release** (`terraform/modules/helm-releases/main.tf`)
   - Deploys VSO operator using official HashiCorp Helm chart
   - Version: 0.9.0

2. **Vault Configuration Module** (`terraform/modules/vault-vso-config/`)
   - Enables KV v2 secrets engine at `kvv2/`
   - Creates demo secrets for webapp and database
   - Configures Kubernetes authentication
   - Creates VSO policy and auth role

### Kubernetes Resources

1. **VaultConnection** - Defines connection to Vault server
2. **VaultAuth** - Configures Kubernetes authentication
3. **VaultStaticSecret** (x2) - Syncs secrets from Vault to K8s
   - `webapp-secret` - Application credentials
   - `database-secret` - Database configuration
4. **Demo Application** - nginx-based web UI displaying synced secrets

### Task Commands

- `task vso-configure` - Configure Vault for VSO (Terraform)
- `task vso-deploy` - Deploy VSO custom resources
- `task vso-status` - Check status of all VSO resources
- `task vso-webapp` - Access demo application (port-forward)
- `task vso-update` - Update secrets in Vault
- `task vso-clean` - Remove VSO demo resources
- `task vso-demo` - Run complete demo workflow

## Prerequisites

Before running the VSO demo, ensure you have:

1. **Kubernetes cluster** running (Minikube, kind, etc.)
2. **Vault deployed** via `task up`
3. **Vault initialised** via `task init`
4. **Vault unsealed** via `task unseal`

## Quick Start

### Step 1: Deploy Complete Stack

```bash
# Deploy Vault and all components (includes VSO)
task up

# Initialise and unseal Vault
task init
task unseal
```

### Step 2: Run VSO Demo

```bash
# Run the complete VSO demo
task vso-demo
```

This command will:
1. Configure Vault (enable KV, create secrets, configure auth)
2. Deploy VSO custom resources
3. Deploy demo application
4. Show status of all resources

### Step 3: Access Demo Application

```bash
# Port-forward to demo app
task vso-webapp
```

Open your browser to http://localhost:8080 to see the demo application displaying secrets synced from Vault.

### Step 4: Test Secret Synchronisation

In a new terminal window:

```bash
# Update secrets in Vault
task vso-update
```

Wait 30 seconds (VSO refresh interval), then refresh the browser to see updated secrets.

## Manual Setup (Step-by-Step)

If you want to understand each step:

### 1. Configure Vault

```bash
# Apply Vault configuration via Terraform
cd terraform
terraform apply -target=module.vault_vso_config -auto-approve
```

This creates:
- KV v2 secrets engine at `kvv2/`
- Secrets at `kvv2/webapp/config` and `kvv2/database/config`
- Kubernetes auth method
- VSO policy with read permissions
- Kubernetes auth role `vso-role`

### 2. Deploy VSO Custom Resources

```bash
# Apply all VSO resources
kubectl apply -f k8s/vso-demo/ -n vault-stack
```

This creates:
- VaultConnection (connection to Vault)
- VaultAuth (authentication configuration)
- VaultStaticSecret resources (secret synchronisation)
- Demo application deployment

### 3. Verify Deployment

```bash
# Check VSO resources
task vso-status
```

You should see:
- ✅ VaultConnection: Connected
- ✅ VaultAuth: Authenticated
- ✅ VaultStaticSecret: Synced
- ✅ Kubernetes secrets created
- ✅ Demo pod running

### 4. Access Application

```bash
# Port-forward to demo app
kubectl port-forward -n vault-stack svc/webapp-service 8080:80
```

Visit http://localhost:8080

## Secrets in Vault

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

## Testing Secret Updates

### Method 1: Using Task Command

```bash
task vso-update
```

### Method 2: Manual Update

```bash
# Access Vault pod
kubectl exec -n vault-stack vault-stack-0 -- vault kv put kvv2/webapp/config \
  username="new-user" \
  password="new-password"
```

VSO will automatically detect the change within 30 seconds and update the Kubernetes secret. The demo application pod will be automatically restarted to pick up the new values.

## Verification

### Check Kubernetes Secrets

```bash
# View synced secrets
kubectl get secrets webapp-secret -n vault-stack -o yaml
kubectl get secrets database-secret -n vault-stack -o yaml
```

### Check VSO Logs

```bash
# View VSO operator logs
kubectl logs -n vault-stack -l app.kubernetes.io/name=vault-secrets-operator -f
```

### Check Demo App Logs

```bash
# View demo application logs
kubectl logs -n vault-stack -l app=webapp
```

## Architecture Details

### VaultConnection

The VaultConnection custom resource defines how VSO connects to Vault:

- **Address**: `http://vault-stack:8200` (in-cluster service)
- **TLS**: Disabled for demo (enable in production)

### VaultAuth

The VaultAuth custom resource defines how VSO authenticates:

- **Method**: Kubernetes
- **Role**: `vso-role`
- **Service Account**: `default`
- **Mount Path**: `kubernetes`

### VaultStaticSecret

VaultStaticSecret resources define which secrets to sync:

- **Mount**: `kvv2` (KV v2 secrets engine)
- **Type**: `kv-v2`
- **Refresh**: Every 30 seconds
- **Auto-restart**: Configured rollout restart targets

## Troubleshooting

### VSO Not Syncing Secrets

1. Check VSO operator is running:
   ```bash
   kubectl get pods -n vault-stack -l app.kubernetes.io/name=vault-secrets-operator
   ```

2. Check VSO logs:
   ```bash
   kubectl logs -n vault-stack -l app.kubernetes.io/name=vault-secrets-operator
   ```

3. Verify Vault authentication:
   ```bash
   kubectl get vaultauth -n vault-stack -o yaml
   ```

### Secrets Not Updating

1. Check refresh interval (default: 30s)
2. Verify VSO has read permissions:
   ```bash
   kubectl exec -n vault-stack vault-stack-0 -- vault read kvv2/data/webapp/config
   ```

3. Check VaultStaticSecret status:
   ```bash
   kubectl get vaultstaticsecret -n vault-stack -o yaml
   ```

### Demo App Not Starting

1. Check if secrets exist:
   ```bash
   kubectl get secrets -n vault-stack | grep -E "webapp|database"
   ```

2. Check pod events:
   ```bash
   kubectl describe pod -n vault-stack -l app=webapp
   ```

## Cleanup

Remove all VSO demo resources:

```bash
task vso-clean
```

This removes:
- Demo application
- VaultStaticSecret resources
- VaultAuth resource
- VaultConnection resource

To also remove Vault configuration (secrets, auth method, policy):

```bash
# Remove entire stack
task clean
```

## Production Considerations

When using VSO in production:

1. **Enable TLS**: Use proper TLS certificates for Vault
2. **Use Dedicated Service Account**: Create specific service account for VSO
3. **Namespace Isolation**: Deploy VSO per namespace for better security
4. **Adjust Refresh Interval**: Balance between responsiveness and load
5. **Monitor VSO**: Set up alerts for sync failures
6. **Use Vault Namespaces**: Isolate secrets by team/environment
7. **Implement RBAC**: Restrict who can create VaultStaticSecret resources
8. **Audit Logging**: Enable Vault audit logs to track secret access

## Additional Resources

- [Vault Secrets Operator Documentation](https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso)
- [VSO Tutorial](https://developer.hashicorp.com/vault/tutorials/kubernetes-introduction/vault-secrets-operator)
- [VSO GitHub Repository](https://github.com/hashicorp/vault-secrets-operator)
- [Kubernetes Auth Method](https://developer.hashicorp.com/vault/docs/auth/kubernetes)

## Demo Workflow Summary

```bash
# 1. Deploy infrastructure
task up && task init && task unseal

# 2. Run VSO demo
task vso-demo

# 3. Access demo application
task vso-webapp  # http://localhost:8080

# 4. Update secrets
task vso-update

# 5. Check status
task vso-status

# 6. Cleanup
task vso-clean
```
