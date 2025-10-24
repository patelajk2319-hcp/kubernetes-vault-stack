# VSO Demo Kubernetes Resources

This directory contains Kubernetes manifests for the Vault Secrets Operator (VSO) demo.

## Files Overview

| File | Description |
|------|-------------|
| `01-vault-connection.yaml` | VaultConnection - Defines connection to Vault server |
| `02-vault-auth.yaml` | VaultAuth - Configures Kubernetes authentication |
| `03-vault-static-secret-webapp.yaml` | VaultStaticSecret - Syncs webapp credentials |
| `04-vault-static-secret-database.yaml` | VaultStaticSecret - Syncs database configuration |
| `05-webapp-deployment.yaml` | Demo application deployment, service, and configmap |

## Resource Types

### 1. VaultConnection

Defines how VSO connects to Vault:

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultConnection
metadata:
  name: vault-connection
spec:
  address: http://vault-stack:8200
  skipTLSVerify: true
```

### 2. VaultAuth

Defines authentication method:

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: vault-auth
spec:
  vaultConnectionRef: vault-connection
  method: kubernetes
  mount: kubernetes
  kubernetes:
    role: vso-role
    serviceAccount: default
```

### 3. VaultStaticSecret

Syncs secrets from Vault to Kubernetes:

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: webapp-secret
spec:
  vaultConnectionRef: vault-connection
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
```

## Deployment Order

The resources should be applied in this order:

1. **VaultConnection** - Establishes connection to Vault
2. **VaultAuth** - Sets up authentication
3. **VaultStaticSecret** - Creates secret synchronisation
4. **Webapp Deployment** - Deploys demo application

Use `kubectl apply -f .` to apply all resources in order.

## Prerequisites

Before applying these resources:

1. Vault must be running and accessible at `http://vault-stack:8200`
2. Vault must be initialised and unsealed
3. Vault Secrets Operator must be deployed
4. Vault must be configured with:
   - KV v2 secrets engine at `kvv2/`
   - Secrets at `kvv2/webapp/config` and `kvv2/database/config`
   - Kubernetes auth method enabled
   - Policy `vso-policy` with read permissions
   - Role `vso-role` for Kubernetes authentication

Run `task vso-configure` to set up Vault automatically.

## Verification

After applying the resources:

```bash
# Check VaultConnection status
kubectl get vaultconnection -n vault-stack

# Check VaultAuth status
kubectl get vaultauth -n vault-stack

# Check VaultStaticSecret status
kubectl get vaultstaticsecret -n vault-stack

# Verify Kubernetes secrets were created
kubectl get secrets webapp-secret database-secret -n vault-stack

# Check demo application
kubectl get pods -l app=webapp -n vault-stack
```

## Secret Synchronisation

VSO automatically:
1. Authenticates to Vault using Kubernetes auth
2. Reads secrets from specified paths
3. Creates/updates Kubernetes secrets
4. Monitors for changes every 30 seconds
5. Triggers pod restarts when secrets change

## Demo Application

The demo application (`05-webapp-deployment.yaml`) is an nginx-based web UI that:

- Reads secrets from environment variables
- Mounts secrets as files in `/etc/secrets/`
- Displays secret values in a web interface
- Automatically restarts when secrets are updated

Access it via:
```bash
kubectl port-forward -n vault-stack svc/webapp-service 8080:80
```

Then open http://localhost:8080

## Cleanup

Remove all resources:
```bash
kubectl delete -f . -n vault-stack
```

Or use:
```bash
task vso-clean
```

## Troubleshooting

### VaultConnection Not Ready

Check Vault accessibility:
```bash
kubectl exec -n vault-stack deployment/vault-secrets-operator-controller-manager -- \
  wget -O- http://vault-stack:8200/v1/sys/health
```

### VaultAuth Failed

Verify Kubernetes auth is configured:
```bash
kubectl exec -n vault-stack vault-stack-0 -- vault auth list
kubectl exec -n vault-stack vault-stack-0 -- vault read auth/kubernetes/config
```

### VaultStaticSecret Not Syncing

Check VSO operator logs:
```bash
kubectl logs -n vault-stack -l app.kubernetes.io/name=vault-secrets-operator -f
```

Check secret permissions:
```bash
kubectl exec -n vault-stack vault-stack-0 -- \
  vault kv get kvv2/webapp/config
```

### Demo App Not Starting

Verify secrets exist:
```bash
kubectl get secrets -n vault-stack | grep -E "webapp|database"
```

Describe the pod:
```bash
kubectl describe pod -n vault-stack -l app=webapp
```

## Production Considerations

For production use:

1. **Enable TLS**: Set `skipTLSVerify: false` and configure proper certificates
2. **Use Dedicated Service Account**: Create a specific service account for the demo app
3. **Adjust Refresh Interval**: Increase `refreshAfter` to reduce load
4. **Add Resource Limits**: Configure appropriate CPU and memory limits
5. **Use Secret Transformations**: Apply transformations if needed
6. **Implement Health Checks**: Add liveness and readiness probes
7. **Enable Pod Security**: Use Pod Security Standards/Admission

## Related Documentation

- [VSO Demo Guide](../../docs/VSO_DEMO.md)
- [Vault VSO Module](../../terraform/modules/vault-vso-config/README.md)
- [VSO Official Docs](https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso)
