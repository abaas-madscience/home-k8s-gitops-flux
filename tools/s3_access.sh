echo "AccessKey: $(kubectl get secret rook-ceph-object-user-knowledgebase-ai-pipeline-user -n rook-ceph -o jsonpath='{.data.AccessKey}' | base64 -d)"
echo "SecretKey: $(kubectl get secret rook-ceph-object-user-knowledgebase-ai-pipeline-user -n rook-ceph -o jsonpath='{.data.SecretKey}' | base64 -d)"
echo "use mcli alias set ceph ACCESSKEY SECRET"

