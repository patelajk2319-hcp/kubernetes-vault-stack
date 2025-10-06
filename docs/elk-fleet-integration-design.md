# ELK Fleet and Elastic Agent Integration Design

## Overview

This document outlines the design for integrating Fleet Server and Elastic Agent into the Kubernetes Vault stack to enable Vault operational and audit log forwarding to Elasticsearch.

## Current Podman Implementation Analysis

### Components
1. **Fleet Server** - Manages Elastic Agent policies and configurations
2. **Elastic Agent** - Collects Vault logs and forwards to Elasticsearch
3. **Vault Audit Logging** - Enabled via `vault audit enable` command

### Key Findings from Podman Stack

#### 1. Fleet Server Configuration
- Image: `docker.elastic.co/beats/elastic-agent:8.12.0`
- Port: `8220`
- Environment:
  - `FLEET_SERVER_ENABLE=1`
  - `FLEET_SERVER_ELASTICSEARCH_HOST=https://elasticsearch:9200`
  - `FLEET_SERVER_POLICY_ID=fleet-server-policy`
  - `FLEET_SERVER_INSECURE_HTTP=true`
  - Uses CA certificates for Elasticsearch connection

#### 2. Elastic Agent Configuration
- Image: `docker.elastic.co/beats/elastic-agent:8.12.0`
- Volumes:
  - `/mnt/vault-logs` - Read-only mount to Vault logs volume
  - Shared token volume for enrollment
- Enrollment handled post-deployment via script

#### 3. Vault Audit Log Configuration
```bash
vault audit enable -path="audit_log" file file_path=/vault/logs/vault_audit.log mode=644
vault audit enable -path="audit_stdout" file file_path=stdout
```

#### 4. Fleet Integration Configuration
The script `30_vault-elk-integration.sh` configures:
- **Audit logs**: `/mnt/vault-logs/vault_audit.log`
- **Operational logs**: `/mnt/vault-logs/*.json`
- **Metrics** (optional): `http://vault:8200/v1/sys/metrics`

### Workflow
1. Deploy Fleet Server (with enrollment token generation)
2. Deploy Elastic Agent
3. Enroll Agent with Fleet Server (automated via script)
4. Enable Vault audit logging to file
5. Configure HashiCorp Vault integration in Fleet
6. Logs flow: Vault → Shared Volume → Elastic Agent → Elasticsearch

## Kubernetes Implementation Plan

### Architecture Changes

#### 1. Fleet Server Deployment
**Approach**: Use ECK (Elastic Cloud on Kubernetes) Agent CRD

```yaml
apiVersion: agent.k8s.elastic.co/v1alpha1
kind: Agent
metadata:
  name: fleet-server
  namespace: vault-stack
spec:
  version: 8.12.0
  mode: fleet
  fleetServerEnabled: true
  deployment:
    replicas: 1
    podTemplate:
      spec:
        serviceAccountName: fleet-server
        automountServiceAccountToken: true
  elasticsearchRefs:
  - name: elasticsearch
```

#### 2. Elastic Agent Deployment
**Approach**: DaemonSet or Deployment with volume mounts

```yaml
apiVersion: agent.k8s.elastic.co/v1alpha1
kind: Agent
metadata:
  name: elastic-agent
  namespace: vault-stack
spec:
  version: 8.12.0
  mode: fleet
  fleetServerRef: fleet-server
  daemonSet:
    podTemplate:
      spec:
        volumes:
        - name: vault-audit-logs
          persistentVolumeClaim:
            claimName: vault-audit-logs
        volumeMounts:
        - name: vault-audit-logs
          mountPath: /mnt/vault-logs
          readOnly: true
```

#### 3. Vault Configuration Changes

**Add to Vault Helm values**:
```yaml
server:
  volumes:
  - name: vault-audit-logs
    persistentVolumeClaim:
      claimName: vault-audit-logs
  volumeMounts:
  - name: vault-audit-logs
    mountPath: /vault/logs

  auditStorage:
    enabled: true
    size: 5Gi
    storageClass: null  # Use default
```

**Post-init script** to enable audit logging:
```bash
vault audit enable -path="audit_log" file \
  file_path=/vault/logs/vault_audit.log \
  mode=0644
```

### Implementation Steps

#### Phase 1: Storage Setup
1. Create PersistentVolumeClaim for Vault audit logs
2. Update Vault Helm chart to mount the volume
3. Modify init script to enable audit logging

#### Phase 2: Fleet Server Deployment
1. Add Fleet Server Agent CRD via Terraform
2. Create Kubernetes Service for Fleet Server
3. Configure Fleet Server policy in Kibana

#### Phase 3: Elastic Agent Deployment
1. Add Elastic Agent Agent CRD via Terraform
2. Mount Vault audit logs volume (ReadOnly)
3. Configure agent enrollment

#### Phase 4: Integration Configuration
1. Create Kubernetes Job to configure HashiCorp Vault integration
2. Configure log paths:
   - Audit: `/mnt/vault-logs/vault_audit.log`
   - Operational: `/mnt/vault-logs/*.json`
3. Optional: Configure metrics collection

### File Structure

```
terraform/
├── modules/
│   └── elk-fleet/
│       ├── main.tf           # Fleet Server and Agent resources
│       ├── variables.tf      # Configuration variables
│       ├── outputs.tf        # Outputs
│       └── scripts/
│           └── configure-vault-integration.sh

scripts/
├── elk/
│   ├── fleet-init.sh         # Initialise Fleet Server
│   └── vault-integration.sh  # Configure Vault integration
```

### Configuration Files

#### Terraform Module (`elk-fleet/main.tf`)
- Fleet Server Agent CRD
- Elastic Agent Agent CRD
- Service for Fleet Server
- ConfigMap for integration scripts
- Job for post-deployment configuration

#### Vault Audit Log PVC
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: vault-audit-logs
  namespace: vault-stack
spec:
  accessModes:
  - ReadWriteMany  # Allow both Vault and Agent to access
  resources:
    requests:
      storage: 5Gi
```

### Task Commands

```yaml
# Taskfile.yaml additions
elk-fleet:
  desc: Configure Fleet Server and Elastic Agent
  cmds:
    - kubectl wait --for=condition=ready agent/fleet-server -n vault-stack --timeout=300s
    - kubectl wait --for=condition=ready agent/elastic-agent -n vault-stack --timeout=300s
    - ./scripts/elk/vault-integration.sh

audit-logs:
  desc: Enable Vault audit logging and configure ELK integration
  deps: [elk-fleet]
  cmds:
    - kubectl exec -n vault-stack vault-stack-0 -- vault audit enable -path="audit_log" file file_path=/vault/logs/vault_audit.log mode=0644
    - sleep 30
    - ./scripts/elk/vault-integration.sh
```

## Migration Considerations

### Differences from Podman
1. **Volume Sharing**: Use ReadWriteMany PVC instead of Docker volumes
2. **Service Discovery**: Use Kubernetes DNS (e.g., `elasticsearch.vault-stack.svc.cluster.local`)
3. **Token Management**: Use Kubernetes Secrets instead of shared volume files
4. **Enrollment**: May need InitContainer or Job for agent enrollment
5. **RBAC**: Fleet Server needs ServiceAccount with appropriate permissions

### Advantages in Kubernetes
1. **Native ECK Integration**: Use ECK Agent CRDs for better lifecycle management
2. **Automatic Scaling**: Fleet Server can be scaled easily
3. **Health Checks**: Kubernetes native health checks and restart policies
4. **Secret Management**: Use Kubernetes Secrets for sensitive data

## Testing Plan

1. **Verify Fleet Server**:
   ```bash
   kubectl get agent -n vault-stack
   kubectl logs -n vault-stack -l agent.k8s.elastic.co/name=fleet-server
   ```

2. **Verify Elastic Agent**:
   ```bash
   kubectl get agent -n vault-stack
   kubectl logs -n vault-stack -l agent.k8s.elastic.co/name=elastic-agent
   ```

3. **Verify Audit Logs**:
   ```bash
   kubectl exec -n vault-stack vault-stack-0 -- ls -la /vault/logs/
   kubectl exec -n vault-stack vault-stack-0 -- cat /vault/logs/vault_audit.log
   ```

4. **Verify in Elasticsearch**:
   ```bash
   curl -k -u elastic:$ELASTIC_PASSWORD \
     https://localhost:9200/_cat/indices/logs-hashicorp_vault*?v
   ```

5. **Verify in Kibana**:
   - Navigate to Discover
   - Search for `logs-hashicorp_vault.audit-*`
   - Verify audit log entries appear

## Next Steps

1. Create Terraform module for Fleet and Agent
2. Update Vault Helm configuration for audit logs
3. Create integration configuration scripts
4. Update Taskfile with new commands
5. Test end-to-end log flow
6. Document in README

## References

- [ECK Agent Documentation](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-elastic-agent.html)
- [Fleet Server Setup](https://www.elastic.co/guide/en/fleet/current/fleet-server.html)
- [HashiCorp Vault Integration](https://docs.elastic.co/integrations/hashicorp_vault)
- [Vault Audit Devices](https://developer.hashicorp.com/vault/docs/audit/file)
