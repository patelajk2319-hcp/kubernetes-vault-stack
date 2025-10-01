
## Overview

This stack deploys a complete Vault Enterprise environment on Kubernetes with:
- **Security**: Vault Enterprise with Raft storage backend
- **Monitoring**: Grafana, Prometheus, Loki, Promtail
- **Data Services**: Redis, Elasticsearch, Kibana
- **Observability**: Unified logging and metrics collection

## Prerequisites

- Kubernetes cluster (1.20+)
- `kubectl` configured and connected to cluster
- `helm` 3.x
- `task` (Task runner) - [Installation](https://taskfile.dev/installation/)
- `jq` (JSON processor)
- Vault Enterprise license (add to `.env` file)

## Quick Start

### 1. Clone Repository

```bash
git clone <repository-url>
cd kubernetes-vault-stack
```

### 2. Deploy the Stack

```bash
task up
```

This command will:
- Check prerequisites
- Create TLS certificates
- Deploy Helm chart with all components
- Set up port-forwarding automatically

### 3. Initialize Vault

```bash
task init
```

This generates:
- Root token (saved to `.env`)
- Unseal key (saved to `vault-init.json`)

### 4. Unseal Vault

```bash
task unseal
```

### 5. View Access Information

```bash
task info
```

## Available Commands

```bash
task              # List all available commands
task up           # Deploy the entire stack
task init         # Initialize Vault
task unseal       # Unseal Vault
task status       # Show status of all components
task info         # Show access information and credentials
task logs         # View logs for a service (usage: task logs -- <service-name>)
task shell        # Open a shell in the Vault pod
task clean        # Destroy the entire stack
task rm           # Alias for clean
```

## Accessing Services

Port-forwarding is automatically configured during `task up`. Services are available at:

- **Vault UI**: http://localhost:8200/ui
- **Vault CLI**: `source .env && vault status`
- **Grafana**: http://localhost:3000
- **Prometheus**: http://localhost:9090
- **Elasticsearch**: https://localhost:9200
- **Kibana**: https://localhost:5601
- **Redis**: localhost:6379

## Credentials

### Vault
After running `task init`, credentials are saved to:
- **Root Token**: `.env` file (also in `vault-init.json`)
- **Unseal Key**: `vault-init.json`

To use Vault CLI:
```bash
source .env
vault status
vault secrets list
```

### Service Credentials

| Service | Username | Password |
|---------|----------|----------|
| Elasticsearch | `elastic` | `password123` |
| Kibana | `elastic` | `password123` |
| Grafana | `admin` | `admin` |
| Redis | `vault-root-user` | `SuperSecretPass123` |

Run `task info` to display all credentials.

## Usage Examples

### View Component Status

```bash
task status
```

Shows:
- Pod status
- Services
- Vault status (initialized, sealed state)

### View Service Logs

```bash
# View Vault logs
task logs -- vault

# View Elasticsearch logs
task logs -- elasticsearch

# View Kibana logs
task logs -- kibana

# Without service name, shows available services
task logs
```

### Access Vault Shell

```bash
task shell
```

Opens an interactive shell inside the Vault pod.

### Clean and Redeploy

```bash
# Destroy everything
task clean    # or: task rm

# Redeploy from scratch
task up
task init
task unseal
```

## Configuration

### Helm Values

Customize the deployment by editing `helm-chart/vault-stack/values.yaml`:

- Resource limits and requests
- Replica counts
- Storage sizes
- Enable/disable components
- **Change default passwords!**

After making changes:

```bash
task clean
task up
```

### Environment Variables

The `.env` file is automatically created and updated during deployment:

```bash
# Vault address - required for Vault CLI commands
export VAULT_ADDR=http://127.0.0.1:8200

# Vault Enterprise license - required for Vault Enterprise features
export VAULT_LICENSE=<your-license-here>

# Vault root token - dynamically generated during 'task init'
export VAULT_TOKEN=<auto-populated>
```

**Note**: Unseal key is stored only in `vault-init.json`, not in `.env`.

## Architecture

### Components

- **Vault Enterprise** - Secret management with Raft storage backend
- **Redis** - Database backend for Vault testing with ACL users
- **Elasticsearch** - Log storage with TLS enabled
- **Kibana** - Log visualization and exploration
- **Prometheus** - Metrics collection and monitoring
- **Grafana** - Unified observability dashboard
- **Loki** - Log aggregation system
- **Promtail** - Log collector for Kubernetes

### TLS/Certificates

TLS certificates are automatically generated for:
- Elasticsearch (with CA, client, and server certs)
- Kibana (with CA verification)
- Fleet Server (for Vault integration)

Certificates are valid for 365 days.

## Troubleshooting

### Check Prerequisites

```bash
task pre-deploy-checks
```

### Pod Not Starting

```bash
# Check pod status
task status

# View pod logs
task logs -- <pod-name>

# Describe pod for events
kubectl describe pod -n vault-stack <pod-name>
```

### Vault is Sealed After Restart

Vault needs to be unsealed after pod restarts:

```bash
task unseal
```

Or manually:

```bash
kubectl exec -n vault-stack vault-0 -- vault status
UNSEAL_KEY=$(cat vault-init.json | jq -r '.unseal_keys_b64[0]')
kubectl exec -n vault-stack vault-0 -- vault operator unseal $UNSEAL_KEY
```

### Port-Forwards Not Responding

Port-forwards are automatically set up. If needed, restart them:

```bash
# Kill existing port-forwards
pkill -f "port-forward.*vault-stack"

# Restart (this is done automatically by task up)
NAMESPACE=vault-stack ./scripts/20_port_forwarding.sh
```

### Cannot Connect to Kubernetes Cluster

```bash
# Check cluster connection
kubectl cluster-info

# Check current context
kubectl config current-context

# List available contexts
kubectl config get-contexts
```

## Security Notes

⚠️ **This configuration is for development/testing purposes:**

- Uses self-signed certificates
- Default passwords in `values.yaml`
- Single Vault unseal key (not recommended for production)
- Secrets stored in Kubernetes secrets (base64 encoded)

## Development

### Adding New Services

1. Add service definition to `helm-chart/vault-stack/templates/`
2. Update `values.yaml` with configuration
3. Add port-forward in `scripts/20_port_forwarding.sh`
4. Update `task info` in `scripts/tools/info.sh`


## Related Projects

- Original Podman version: [podman-vault-stack](https://github.com/patelajk2319-hcp/podman-vault-stack)
