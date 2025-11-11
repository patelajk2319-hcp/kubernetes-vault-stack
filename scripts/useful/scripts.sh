#!/bin/bash

# View the ELK dynamic cred created by Vault in Kubernetes
kubectl get secret elasticsearch-dynamic-secret -n vault-stack -o jsonpath="{.data.username}" | base64 -d && echo

kubectl get secret elasticsearch-dynamic-secret -n vault-stack -o jsonpath='{.data.password}' | base64 -d && echo

# Check if Vault can communicate with ELK
kubectl exec -n vault-stack -it vault-stack-0 -- wget -qO- https://host.minikube.internal:9200 --no-check-certificate

kubectl exec -n vault-stack -it vault-stack-0 -- nslookup host.minikube.internal

# Get credentials
USERNAME=$(kubectl get secret elasticsearch-dynamic-secret -n vault-stack -o jsonpath='{.data.username}' | base64 -d)
PASSWORD=$(kubectl get secret elasticsearch-dynamic-secret -n vault-stack -o jsonpath='{.data.password}' | base64 -d)

# curl to ELK
curl -k -u "$USERNAME:$PASSWORD" https://localhost:9200/_cluster/health

netstat -rn

vault kv get kvv2/webapp/config

vault kv list kvv2/elasticsearch
vault kv get kvv2/elasticsearch/config

# List the roles at the mount
vault list database/roles

# Create a dynamic cred
vault read database/creds/elasticsearch-role

# View a dynamic role and the creation statement
vault read database/roles/elasticsearch-role
