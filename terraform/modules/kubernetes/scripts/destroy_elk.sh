#!/bin/bash

# Destroy Elasticsearch and Kibana resources
# This script removes the ECK-managed resources

set -e

NAMESPACE="${NAMESPACE:-vault-stack}"

echo "Destroying ELK stack resources..."

kubectl delete kibana kibana -n "$NAMESPACE" --ignore-not-found=true
kubectl delete elasticsearch elasticsearch -n "$NAMESPACE" --ignore-not-found=true

echo "ELK stack resources destroyed"
