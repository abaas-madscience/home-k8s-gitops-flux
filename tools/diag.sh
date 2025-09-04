#!/bin/bash
echo "=== Resources with deletion timestamps ==="
kubectl get all --all-namespaces -o json | jq -r '.items[] | select(.metadata.deletionTimestamp != null) | "\(.kind)/\(.metadata.name) in \(.metadata.namespace // "default")"'

echo -e "\n=== Terminating namespaces ==="
kubectl get ns | grep Terminating

echo -e "\n=== Pods with finalizers ==="
kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.metadata.finalizers != null and (.metadata.finalizers | length > 0)) | "\(.metadata.namespace)/\(.metadata.name): \(.metadata.finalizers[])"'
