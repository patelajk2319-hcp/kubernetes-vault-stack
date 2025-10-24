# VSO Demo - Quick Start Guide

Get the Vault Secrets Operator demo running in under 5 minutes.

## Prerequisites

- Minikube or Kubernetes cluster
- kubectl configured
- Task installed
- Terraform installed

## Quick Start

### 1. Deploy Vault Stack

```bash
# Start Minikube (if using Minikube)
minikube start

# Deploy entire stack
task up

# Wait for Vault pod to be running
kubectl wait --for=condition=ready pod/vault-stack-0 -n vault-stack --timeout=120s
```

### 2. Initialise and Unseal Vault

```bash
# Initialise Vault (creates root token and unseal keys)
task init

# Unseal Vault and set up port-forwarding
task unseal
```

**Important**: After running `task init`, save the root token and unseal keys displayed in the terminal!

### 3. Run VSO Demo

```bash
# Run complete VSO demo workflow
task vso-demo
```

This command will:
1. Configure Vault (enable KV, create secrets, setup auth)
2. Deploy VSO custom resources
3. Deploy demo application
4. Show status of all resources

Expected output:
```
✅ VSO Demo deployed successfully!

Next steps:
  1. Run 'task vso-webapp' to access the demo application
  2. Run 'task vso-update' to update secrets and watch them sync
  3. Run 'task vso-status' to check synchronisation status
```

### 4. Access Demo Application

```bash
# Port-forward to demo app
task vso-webapp
```

Open http://localhost:8080 in your browser.

You should see a web page displaying:
- **Web Application Credentials** (username and password)
- **Database Configuration** (host, port, database, username, password)

### 5. Test Secret Synchronisation

Open a new terminal and run:

```bash
# Update secrets in Vault
task vso-update
```

Wait 30 seconds, then **refresh your browser**. The secrets should automatically update!

## What Just Happened?

1. **Vault Configuration**: Terraform created:
   - KV v2 secrets engine
   - Demo secrets in Vault
   - Kubernetes authentication method
   - VSO policy and role

2. **VSO Deployment**: Kubernetes applied:
   - VaultConnection (connection config)
   - VaultAuth (authentication config)
   - VaultStaticSecret resources (secret sync)
   - Demo application

3. **Secret Synchronisation**: VSO automatically:
   - Authenticated to Vault
   - Read secrets from Vault
   - Created Kubernetes secrets
   - Injected secrets into demo pod

4. **Auto-Update**: When you updated Vault secrets:
   - VSO detected the change
   - Updated Kubernetes secrets
   - Restarted the demo pod
   - New secrets appeared in the web UI

## Verify Everything

```bash
# Check all VSO resources
task vso-status
```

You should see:
- ✅ VaultConnection: Connected
- ✅ VaultAuth: Authenticated
- ✅ VaultStaticSecret: Synced
- ✅ Kubernetes secrets: Created
- ✅ Demo pod: Running

## Troubleshooting

### Vault Not Starting

```bash
# Check Vault pod status
kubectl get pods -n vault-stack

# Check Vault logs
kubectl logs -n vault-stack vault-stack-0
```

### VSO Not Syncing

```bash
# Check VSO operator logs
kubectl logs -n vault-stack -l app.kubernetes.io/name=vault-secrets-operator

# Verify Vault is accessible
kubectl exec -n vault-stack deployment/vault-secrets-operator-controller-manager -- \
  wget -O- http://vault-stack:8200/v1/sys/health
```

### Demo App Not Loading

```bash
# Check if secrets exist
kubectl get secrets webapp-secret database-secret -n vault-stack

# Check pod status
kubectl describe pod -n vault-stack -l app=webapp

# Check pod logs
kubectl logs -n vault-stack -l app=webapp
```

## Cleanup

```bash
# Remove VSO demo resources only
task vso-clean

# Remove entire stack
task clean
```

## Next Steps

- Read the [full VSO demo documentation](./VSO_DEMO.md)
- Explore the [Terraform VSO module](../terraform/modules/vault-vso-config/README.md)
- Check out the [Kubernetes resources](../k8s/vso-demo/README.md)
- Try updating secrets manually with `vault kv put`

## Manual Secret Update

Instead of using `task vso-update`, you can manually update secrets:

```bash
# Set Vault environment variables
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=<your-root-token>

# Update webapp secret
vault kv put kvv2/webapp/config \
  username="my-custom-user" \
  password="my-custom-password"

# Update database secret
vault kv put kvv2/database/config \
  db_host="postgres.example.com" \
  db_port="5432" \
  db_name="production" \
  db_username="produser" \
  db_password="prodpass123"
```

Wait 30 seconds and refresh the demo webapp!

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Kubernetes Cluster                       │
│                                                                  │
│  ┌──────────────┐      ┌──────────────────┐                    │
│  │   Vault Pod  │◄─────┤  VSO Operator    │                    │
│  │              │      │  Controller      │                    │
│  └──────────────┘      └────────┬─────────┘                    │
│         ▲                        │                               │
│         │ (Kubernetes Auth)      │ (watches & syncs)            │
│         │                        ▼                               │
│  ┌──────┴───────┐      ┌──────────────────┐                    │
│  │  KV Secrets  │      │   K8s Secrets    │                    │
│  │  kvv2/       │      │  - webapp-secret │                    │
│  │  - webapp    │      │  - database-secret│                   │
│  │  - database  │      └────────┬─────────┘                    │
│  └──────────────┘               │ (mounted as env vars)         │
│                                  ▼                               │
│                        ┌──────────────────┐                    │
│                        │  Demo Web App    │                    │
│                        │  (nginx)         │                    │
│                        └──────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

## Key Concepts

- **VaultConnection**: Tells VSO where Vault is
- **VaultAuth**: Tells VSO how to authenticate
- **VaultStaticSecret**: Tells VSO which secrets to sync
- **Refresh Interval**: How often VSO checks for changes (30s)
- **Rollout Restart**: Automatic pod restart when secrets change

## Complete Demo Workflow

```bash
# 1. Infrastructure
task up && task init && task unseal

# 2. VSO Demo
task vso-demo

# 3. Access Application
task vso-webapp  # http://localhost:8080

# 4. Update Secrets
task vso-update  # In new terminal

# 5. Check Status
task vso-status

# 6. Cleanup
task vso-clean
```

That's it! You now have a working Vault Secrets Operator demo. 🎉
