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

- Kubernetes cluster (1.20+)
- `kubectl`, `terraform` (>= 1.5.0), `task`, `jq`
- Vault Enterprise licence

## Quick Start

### 1. Add Vault Licence

```bash
cp licenses/vault-enterprise/license.lic.example licenses/vault-enterprise/license.lic
# Edit license.lic and add your Vault Enterprise licence
```

### 2. Deploy

```bash
task up        # Deploy infrastructure
task init      # Initialise Vault
task unseal    # Unseal Vault
```

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

### Static Secrets (VSO)

VSO synchronises Vault secrets to Kubernetes secrets automatically.

```bash
task vso           # Deploy demo
task vso-update    # Update secrets to test sync
task info          # View credentials
```

### Dynamic Credentials

Vault generates time-limited Elasticsearch credentials that rotate automatically.

```bash
task elk:dynamic   # Deploy demo (alias: dynamic)
task info          # View current credentials
```

**Features:**
- Auto-generated unique users
- 5-minute credential lifetime
- 60-second rotation interval
- Automatic revocation

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
