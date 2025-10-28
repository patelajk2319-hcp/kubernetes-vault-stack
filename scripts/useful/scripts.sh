#view the elk dynamic cred created by vault in kubernetes
kubectl get secret elasticsearch-dynamic-secret -n vault-stack -o jsonpath="{.data.username}" | base64 -d && echo

#view the elk dynamic cred created by vault in kubernetes
kubectl get secret elasticsearch-dynamic-secret -n vault-stack -o jsonpath='{.data.password}' | base64 -d && echo

#check if vault can speak to elk - will get 401 as no elk creds are been passed but this is ok
kubectl exec -n vault-stack -it vault-stack-0 -- wget -qO- https://host.minikube.internal:9200 --no-check-certificate

kubectl exec -n vault-stack -it vault-stack-0 -- nslookup host.minikube.internal

netstat -rn

vault kv get kvv2/webapp/config

vault kv list kvv2/elasticsearch
vault kv get kvv2/elasticsearch/config

#list the roles at the mount
vault list database/roles
#create a dynamic cred
vault read database/creds/elasticsearch-role

#view a dynamic role and the creation statement
vault read database/roles/elasticsearch-role
