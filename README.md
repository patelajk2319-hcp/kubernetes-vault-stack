# Kubernetes Vault Stack

HashiCorp Vault Enterprise deployment on Kubernetes with Vault Secrets Operator, ELK stack, and observability tools.

## Features

- **Vault Enterprise** - Raft storage backend
- **Vault Secrets Operator (VSO)** - Native Kubernetes secret synchronisation
- **ELK Stack** - Elasticsearch, Kibana (via ECK)
- **Observability** - Grafana, Prometheus, Loki, Promtail
- **Dynamic Secrets** - Time-limited Elasticsearch credentials
- **TLS Everywhere** - Automatic certificate generation

## Prerequisites

### System Requirements

- [Homebrew](https://brew.sh) package manager
- Vault Enterprise licence

### Install Dependencies

```bash
# Install required tools via Homebrew
brew install minikube kubectl terraform go-task jq podman

# Start Kubernetes cluster
minikube start --driver=podman

# Verify cluster is running
kubectl cluster-info
```

## Quick Start

### 1. Add Vault Licence

```bash
cp licenses/vault-enterprise/license.lic.example licenses/vault-enterprise/license.lic
# Edit license.lic and add your Vault Enterprise licence
```

### 2. Deploy Full Infrastructure

```bash
task up        # Deploy Kubernetes + ELK stack
task init      # Initialise Vault
task unseal    # Unseal Vault
task audit     # Configure audit logging
task vso       # Deploy Vault Secrets Operator
```

This deploys the complete infrastructure including Vault, ELK observability stack, audit logging, and VSO for secret synchronisation.

### 3. Access Services

Services are available at:
- **Vault**: http://localhost:8200
- **Kibana**: https://localhost:5601
- **Elasticsearch**: https://localhost:9200
- **Grafana**: http://localhost:3000
- **Prometheus**: http://localhost:9090

```bash
source .env    # Load Vault credentials
vault status
task info      # View all access information
```

## Available Commands

```bash
task               # List all commands
task up            # Deploy stack
task init          # Initialise Vault
task unseal        # Unseal Vault
task status        # Show component status
task info          # Show credentials
task logs          # View service logs
task vso           # Deploy VSO static secrets demo
task elk:dynamic   # Deploy dynamic credentials demo (alias: dynamic)
task clean         # Destroy stack (alias: rm)
```

## Demos

After deploying the full infrastructure (see Quick Start), you can explore advanced features:

### Dynamic Credentials Demo

Vault generates time-limited Elasticsearch credentials that rotate automatically.

```bash
task elk:dynamic   # Deploy dynamic credentials demo (alias: dynamic)
task info          # View current credentials
```

**Features:**
- Auto-generated unique users with random names
- 5-minute credential lifetime
- 60-second rotation interval
- Automatic revocation when lease expires

**How it works:**
1. VSO requests Elasticsearch credentials from Vault
2. Vault creates a time-limited user in Elasticsearch
3. Credentials are synchronised to a Kubernetes secret
4. VSO automatically renews credentials before expiry
5. When the secret is deleted, Vault revokes the Elasticsearch user

## Configuration

### Terraform Variables

`terraform/tf-core/variables.tf`:

```hcl
namespace            = "vault-stack"
cert_validity_hours  = 8760  # 1 year
```

### Helm Values

Values files in `helm-chart/vault-stack/values/`:
- `vault/vault.yaml` - Vault configuration
- `grafana/grafana.yaml` - Grafana settings
- `prometheus/prometheus.yaml` - Prometheus settings
- `loki/loki.yaml` - Loki settings

Modify values, then redeploy:
```bash
task clean && task up && task init && task unseal
```

## Troubleshooting

### Vault Sealed After Restart

```bash
task unseal
```

### Port-Forwarding Issues

```bash
./scripts/20_port_forwarding.sh
```

### Check Prerequisites

```bash
task pre-deploy-checks
```

### Pod Logs

```bash
task logs -- <pod-name>
kubectl describe pod -n vault-stack <pod-name>
```

### Kibana Login with Dynamic Credentials

Dynamic credentials require `allow_restricted_indices: true` for Kibana system indices. This is automatically configured by `task elk:dynamic`.

Verify:
```bash
curl -k -u elastic:password123 "https://localhost:9200/_security/role/vault_es_role" | jq '.vault_es_role.indices[0].allow_restricted_indices'
```

Should return `true`.

## Architecture

All components use official Helm charts:

- **Vault Enterprise** (HashiCorp)
- **Vault Secrets Operator** (HashiCorp)
- **Elasticsearch + Kibana** (Elastic via ECK)
- **Prometheus** (Prometheus Community)
- **Grafana** (Grafana Labs)
- **Loki + Promtail** (Grafana Labs)

TLS certificates are automatically generated via Terraform's `tls` provider.

## Development

To add new services:
1. Add Helm chart to `terraform/tf-core/modules/helm-releases/main.tf`
2. Create values file in `helm-chart/vault-stack/values/<service>/`
3. Add port-forwarding to `scripts/20_port_forwarding.sh` if needed
4. Update `scripts/tools/info.sh` for credentials

## Cleaning Up

```bash
task clean    # or: task rm
```

Removes all infrastructure including Kubernetes resources, PVs, and local files.
