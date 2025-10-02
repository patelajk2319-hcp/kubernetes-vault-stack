#!/bin/bash

# Deploy Elasticsearch and Kibana via ECK operator
# This script waits for ECK CRDs to be available and then deploys the resources

set -e

NAMESPACE="${NAMESPACE:-vault-stack}"

echo "Waiting for ECK operator CRDs to be ready..."

# Wait for ECK operator pod to be running
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=elastic-operator -n "$NAMESPACE" --timeout=120s || true

# Retry loop for CRD availability (max 3 minutes)
for i in {1..18}; do
  if kubectl get crd elasticsearches.elasticsearch.k8s.elastic.co >/dev/null 2>&1; then
    echo "ECK CRDs are ready"
    break
  fi
  echo "Waiting for ECK CRDs... (attempt $i/18)"
  sleep 10
done

# Deploy Elasticsearch
cat <<EOF | kubectl apply -f -
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: elasticsearch
  namespace: $NAMESPACE
spec:
  version: 8.12.0
  nodeSets:
  - name: default
    count: 1
    config:
      node.store.allow_mmap: false
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 20Gi
    podTemplate:
      spec:
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 512Mi
              cpu: 500m
            limits:
              memory: 1Gi
              cpu: 1000m
EOF

# Wait a bit for Elasticsearch to start creating
sleep 10

# Deploy Kibana
cat <<EOF | kubectl apply -f -
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: kibana
  namespace: $NAMESPACE
spec:
  version: 8.12.0
  count: 1
  elasticsearchRef:
    name: elasticsearch
  podTemplate:
    spec:
      containers:
      - name: kibana
        resources:
          requests:
            memory: 512Mi
            cpu: 500m
          limits:
            memory: 1Gi
            cpu: 1000m
EOF

echo "ELK stack deployed successfully"
