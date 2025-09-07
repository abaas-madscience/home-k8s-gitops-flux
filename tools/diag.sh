#!/bin/bash
echo "=== Resources with deletion timestamps ==="
kubectl get all --all-namespaces -o json | jq -r '.items[] | select(.metadata.deletionTimestamp != null) | "\(.kind)/\(.metadata.name) in \(.metadata.namespace // "default")"'

echo -e "\n=== Terminating namespaces ==="
kubectl get ns | grep Terminating || echo "None found"

echo -e "\n=== Pods with finalizers ==="
kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.metadata.finalizers != null and (.metadata.finalizers | length > 0)) | "\(.metadata.namespace)/\(.metadata.name): \(.metadata.finalizers[])"'

echo -e "\n=== Stuck PVCs/PVs (not Bound/Available) ==="
kubectl get pvc,pv --all-namespaces | grep -v -E "Bound|Available" | grep -v "STATUS" || echo "None found"

echo -e "\n=== Failed Flux Resources ==="
kubectl get kustomizations,helmreleases,helmrepositories,ocirepositories --all-namespaces | grep -v -E "True|Ready" | grep -v "STATUS" || echo "None found"

echo -e "\n=== Helm Charts with issues ==="
kubectl get helmcharts --all-namespaces | grep -v "True" | grep -v "STATUS" || echo "None found"
