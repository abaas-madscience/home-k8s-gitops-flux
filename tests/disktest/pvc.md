# Create PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-perf-test-pvc
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: longhorn
  resources:
    requests:
      storage: 5Gi
EOF

# Deploy test (replace PVC name in deployment)
sed 's/REPLACE_WITH_YOUR_PVC_NAME/longhorn-perf-test-pvc/' storage-perf-test-deployment.yaml | kubectl apply -f -


################

# Create PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: openebs-perf-test-pvc
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: openebs-hostpath
  resources:
    requests:
      storage: 5Gi
EOF

# Deploy test
sed 's/REPLACE_WITH_YOUR_PVC_NAME/openebs-perf-test-pvc/' storage-perf-test-deployment.yaml | kubectl apply -f -


#################
