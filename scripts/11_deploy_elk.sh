#!/bin/bash

# Deploy Elasticsearch and Kibana after ECK operator is ready
# This script must be run AFTER the main stack deployment

set -e

# Source centralized color configuration
source "$(dirname "$0")/lib/colors.sh"

NAMESPACE="${NAMESPACE:-vault-stack}"

echo -e "${BLUE}Waiting for ECK operator to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=elastic-operator -n "$NAMESPACE" --timeout=120s

echo -e "${BLUE}Checking if ECK CRDs are installed...${NC}"
if ! kubectl get crd elasticsearches.elasticsearch.k8s.elastic.co &>/dev/null; then
  echo -e "${YELLOW}ECK CRDs not found. Waiting for operator to create them...${NC}"
  sleep 10
fi

echo -e "${GREEN}ECK operator is ready${NC}"

echo -e "${BLUE}Deploying Elasticsearch...${NC}"
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

echo -e "${GREEN}Elasticsearch deployment created${NC}"

echo -e "${BLUE}Waiting for Elasticsearch to be ready...${NC}"
kubectl wait --for=jsonpath='{.status.phase}'=Ready elasticsearch/elasticsearch -n "$NAMESPACE" --timeout=300s || true

echo -e "${BLUE}Deploying Kibana...${NC}"
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

echo -e "${GREEN}Kibana deployment created${NC}"

echo -e "${BLUE}Waiting for Kibana to be ready...${NC}"
kubectl wait --for=jsonpath='{.status.health}'=green kibana/kibana -n "$NAMESPACE" --timeout=300s || true

echo ""
echo -e "${GREEN}ELK stack deployed successfully!${NC}"
echo ""
echo -e "${BLUE}Elasticsearch and Kibana status:${NC}"
kubectl get elasticsearch,kibana -n "$NAMESPACE"
