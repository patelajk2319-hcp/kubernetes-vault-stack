#!/bin/bash
set -e

NAMESPACE="vault-stack"

echo "🗑️  Cleaning up Vault Stack from Kubernetes"
echo "============================================"
echo ""

echo "⚠️  WARNING: This will delete all resources in the ${NAMESPACE} namespace!"
echo "Press Enter to continue or Ctrl+C to cancel..."
read

echo "Deleting all resources..."

# Delete deployments and statefulsets
kubectl delete deployment --all -n ${NAMESPACE} 2>/dev/null || true
kubectl delete statefulset --all -n ${NAMESPACE} 2>/dev/null || true
kubectl delete daemonset --all -n ${NAMESPACE} 2>/dev/null || true
kubectl delete job --all -n ${NAMESPACE} 2>/dev/null || true

# Delete services
kubectl delete service --all -n ${NAMESPACE} 2>/dev/null || true

# Delete configmaps and secrets
kubectl delete configmap --all -n ${NAMESPACE} 2>/dev/null || true
kubectl delete secret --all -n ${NAMESPACE} 2>/dev/null || true

# Delete PVCs
kubectl delete pvc --all -n ${NAMESPACE} 2>/dev/null || true

# Delete namespace
kubectl delete namespace ${NAMESPACE} 2>/dev/null || true

# Delete local cert files
echo "Deleting local certificate files..."
rm -rf certs

echo ""
echo "✅ Cleanup complete!"