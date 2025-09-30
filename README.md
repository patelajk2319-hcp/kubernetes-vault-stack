# Kubernetes Vault Stack

A production-ready Kubernetes deployment of HashiCorp Vault Enterprise with full observability stack including Prometheus, Grafana, Loki, Elasticsearch, and Kibana.

## Architecture

This stack includes:
- **Vault Enterprise**: Secret management with Raft storage backend
- **Redis**: Database backend for Vault testing
- **Elasticsearch & Kibana**: Log aggregation and visualization (with TLS)
- **Prometheus**: Metrics collection
- **Grafana**: Unified observability dashboard
- **Loki & Promtail**: Log aggregation for Kubernetes

## Prerequisites

- Kubernetes cluster (1.20+)
- kubectl configured and connected to your cluster
- OpenSSL (for certificate generation)
- Vault CLI (for initialization)
- Valid Vault Enterprise license

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/patelajk2319-hcp/kubernetes-vault-stack.git
cd kubernetes-vault-stack
```

### 2. Configure Secrets

Edit `manifests/base/secrets.yaml` and add your base64-encoded Vault Enterprise license:

```bash
echo -n "YOUR_VAULT_LICENSE" | base64
```

Replace `REPLACE_WITH_BASE64_ENCODED_VAULT_LICENSE` with the output.

### 3. Deploy the Stack

```bash
./deploy.sh
```

This script will:
- Create the namespace
- Generate TLS certificates for Elasticsearch and Kibana
- Create all necessary Kubernetes resources
- Deploy all services

### 4. Initialize Vault

After deployment completes, initialize Vault:

```bash
kubectl apply -f manifests/vault/init-job.yaml
```

Retrieve the initialization data from the job logs:

```bash
kubectl logs -n vault-stack job/vault-init
```

**⚠️ IMPORTANT**: Save the unseal keys and root token securely!

### 5. Access Services

Get your node IP:

```bash
kubectl get nodes -o wide
```

Access the services:
- **Vault UI**: `http://<node-ip>:30820`
- **Grafana**: `http://<node-ip>:30300` (admin/admin)
- **Prometheus**: `http://<node-ip>:30909`
- **Kibana**: `https://<node-ip>:30561` (elastic/password123)

## Manual Deployment

If you prefer to deploy components individually:

### 1. Create Namespace

```bash
kubectl apply -f manifests/base/namespace.yaml
```

### 2. Create PVCs

```bash
kubectl apply -f manifests/base/persistent-volumes.yaml
```

### 3. Create Secrets

```bash
kubectl apply -f manifests/base/secrets.yaml
```

### 4. Generate Certificates

```bash
./scripts/00_create-certs.sh
./scripts/create-k8s-secrets.sh
```

### 5. Create ConfigMaps

```bash
kubectl apply -f manifests/vault/configmap.yaml
kubectl apply -f manifests/redis/configmap.yaml
kubectl apply -f manifests/prometheus/configmap.yaml
kubectl apply -f manifests/loki/configmap.yaml
kubectl apply -f manifests/promtail/configmap.yaml
kubectl apply -f manifests/grafana/configmap.yaml
```

### 6. Deploy Services

```bash
# Vault
kubectl apply -f manifests/vault/statefulset.yaml
kubectl apply -f manifests/vault/service.yaml

# Redis
kubectl apply -f manifests/redis/deployment.yaml
kubectl apply -f manifests/redis/service.yaml

# Elasticsearch
kubectl apply -f manifests/elasticsearch/statefulset.yaml
kubectl apply -f manifests/elasticsearch/service.yaml

# Kibana
kubectl apply -f manifests/kibana/deployment.yaml
kubectl apply -f manifests/kibana/service.yaml

# Prometheus
kubectl apply -f manifests/prometheus/deployment.yaml
kubectl apply -f manifests/prometheus/service.yaml

# Loki
kubectl apply -f manifests/loki/deployment.yaml
kubectl apply -f manifests/loki/service.yaml

# Promtail
kubectl apply -f manifests/promtail/daemonset.yaml

# Grafana
kubectl apply -f manifests/grafana/deployment.yaml
kubectl apply -f manifests/grafana/service.yaml
```

## Vault Operations

### Unseal Vault (after restart)

If Vault becomes sealed after a pod restart:

```bash
# Using the stored init data
kubectl exec -n vault-stack vault-0 -- vault operator unseal <key-1>
kubectl exec -n vault-stack vault-0 -- vault operator unseal <key-2>
kubectl exec -n vault-stack vault-0 -- vault operator unseal <key-3>
```

Or use the unseal job (if you have persistent storage):

```bash
kubectl apply -f manifests/vault/init-job.yaml
```

### Check Vault Status

```bash
kubectl exec -n vault-stack vault-0 -- vault status
```

### Access Vault CLI

```bash
kubectl exec -it -n vault-stack vault-0 -- /bin/sh
export VAULT_TOKEN=<your-root-token>
vault status
```

## Monitoring

### Grafana Dashboards

Access Grafana at `http://<node-ip>:30300`

- **Username**: admin
- **Password**: admin

Pre-configured data sources:
- Prometheus (metrics)
- Loki (logs)

### Prometheus

Access Prometheus at `http://<node-ip>:30909`

Vault metrics are automatically scraped from `/v1/sys/metrics`

### Kibana

Access Kibana at `https://<node-ip>:30561`

- **Username**: elastic
- **Password**: password123

**Note**: You'll need to accept the self-signed certificate warning in your browser.

## Storage

All data is persisted using PersistentVolumeClaims:

- `vault-data-pvc`: Vault Raft storage (10Gi)
- `vault-logs-pvc`: Vault audit logs (5Gi)
- `redis-data-pvc`: Redis data (5Gi)
- `elasticsearch-data-pvc`: Elasticsearch indices (20Gi)
- `kibana-data-pvc`: Kibana data (5Gi)
- `grafana-data-pvc`: Grafana dashboards (5Gi)
- `prometheus-data-pvc`: Prometheus metrics (10Gi)
- `loki-data-pvc`: Loki logs (10Gi)
- `promtail-data-pvc`: Promtail positions (5Gi)

## Security Considerations

### Production Deployment

For production use, consider:

1. **Secrets Management**: Use Sealed Secrets or External Secrets Operator instead of plain Kubernetes secrets
2. **TLS for Vault**: Enable TLS for Vault API
3. **Network Policies**: Implement network policies to restrict pod-to-pod communication
4. **RBAC**: Configure fine-grained RBAC policies
5. **Storage Classes**: Use appropriate storage classes with encryption
6. **Vault Auto-Unseal**: Configure auto-unseal using cloud KMS
7. **High Availability**: Deploy multiple Vault replicas with Raft
8. **Backup Strategy**: Implement regular backups of Vault data and Elasticsearch indices

### Certificate Management

The included certificates are self-signed and valid for 365 days. For production:
- Use cert-manager to manage certificates
- Use proper CA-signed certificates
- Implement certificate rotation

## Cleanup

To remove all resources:

```bash
./cleanup.sh
```

**⚠️ WARNING**: This will delete all data including PVCs!

## Troubleshooting

### Vault won't start

Check logs:
```bash
kubectl logs -n vault-stack vault-0
```

### Elasticsearch won't start

Ensure `vm.max_map_count` is set correctly on nodes:
```bash
# On each node
sudo sysctl -w vm.max_map_count=262144
```

### Pod stuck in Pending

Check PVC status:
```bash
kubectl get pvc -n vault-stack
```

Ensure your cluster has a default storage class:
```bash
kubectl get storageclass
```

### View all resources

```bash
kubectl get all -n vault-stack
```

## Directory Structure

```
.
├── manifests/
│   ├── base/
│   │   ├── namespace.yaml
│   │   ├── persistent-volumes.yaml
│   │   └── secrets.yaml
│   ├── vault/
│   │   ├── configmap.yaml
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   └── init-job.yaml
│   ├── redis/
│   ├── elasticsearch/
│   ├── kibana/
│   ├── grafana/
│   ├── prometheus/
│   ├── loki/
│   └── promtail/
├── scripts/
│   ├── 00_create-certs.sh
│   ├── create-k8s-secrets.sh
│   ├── vault-init.sh
│   └── vault-unseal.sh
├── deploy.sh
├── cleanup.sh
└── README.md
```

## Differences from Podman Stack

Key changes from the original Podman stack:
- No Fleet Server or Elastic Agents (as requested)
- Uses Kubernetes native resources (Deployments, StatefulSets, Services)
- PersistentVolumeClaims for storage instead of named volumes
- ConfigMaps and Secrets for configuration
- NodePort services for external access
- DaemonSet for Promtail instead of sidecar containers
- Kubernetes Jobs for Vault initialization

## Contributing

Issues and pull requests are welcome!

## License

This project is provided as-is for demonstration purposes.