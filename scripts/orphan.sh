#!/bin/bash

echo "Listing orphaned resources in the cluster..."
echo "---------------------------------------------"

# 1. Pods without ownerReferences (including terminated pods)
echo "Pods without ownerReferences:"
kubectl get pods --all-namespaces -o jsonpath='{.items[*].metadata.ownerReferences}' | grep -v 'null' | jq .metadata.name

# 2. Jobs without ownerReferences (completed jobs)
echo "Jobs without ownerReferences:"
kubectl get jobs --all-namespaces -o jsonpath='{.items[*].metadata.ownerReferences}' | grep -v 'null' | jq .metadata.name

# 3. PersistentVolumes with StorageClass reclaimPolicy=Delete
echo "PVs with StorageClass reclaimPolicy=Delete:"
kubectl get pv --all-namespaces -o jsonpath='{.items[*].spec.storageClassName}' | while read -r storageclass; do
    kubectl get storageclass "$storageclass" -o jsonpath='{.spec.reclaimPolicy}' | grep -q 'Delete' && echo "PV with StorageClass $storageclass"
done

# 4. CertificateSigningRequests (stale/expired)
echo "Stale or expired CSRs:"
kubectl get csr --all-namespaces -o jsonpath='{.items[*].metadata.name}' | while read -r csr; do
    kubectl get csr "$csr" -o jsonpath='{.status.conditions[?(@.type=="Approved")].status}' | grep -q 'True' || echo "CSR: $csr"
done

# 5. NodeLease objects (orphaned if node is deleted)
echo "Orphaned NodeLease objects:"
kubectl get nodeselector --all-namespaces -o jsonpath='{.items[*].metadata.name}' | while read -r lease; do
    kubectl get nodelease "$lease" -o jsonpath='{.metadata.ownerReferences}' | grep -q 'null' && echo "NodeLease: $lease"
done

# 6. General objects without ownerReferences
echo "Other objects without ownerReferences:"
kubectl api-resources --verbs=list --output=name | while read -r resource; do
    kubectl get "$resource" --all-namespaces -o jsonpath='{.items[*].metadata.ownerReferences}' | grep -v 'null' | jq .metadata.name
done
