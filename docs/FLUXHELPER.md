kubectl get kustomizations -A


kubectl delete kustomization <name> -n flux-system

kubectl rollout restart deployment -n flux-system


flux reconcile source git flux-system --with-source


flux reconcile kustomization flux-system --with-source
flux reconcile kustomization infra-cilium --with-source


# Gateway
k describe gateway -n hypercube-test hypercube-gateway


# Rollout
kubectl rollout restart deployment harbor-core harbor-portal -n harbor


# DELETE all error pods
kubectl get pods --all-namespaces | grep -E 'Error|CrashLoopBackOff|ImagePullBackOff|Evicted|Failed|Pending' | awk '{print $2 " -n " $1}' | xargs -L1 kubectl delete pod

kubectl get pods --all-namespaces | grep -E 'Completed' | awk '{print $2 " -n " $1}' | xargs -L1 kubectl delete pod


kubectl get pods --all-namespaces | grep -E 'ContainerStatusUnknown' | awk '{print $2 " -n " $1}' | xargs -L1 kubectl delete pod


# CHECK TO SEE IF The correct helmrelease is applied
kubectl get helmrelease opencost -n flux-system -o yaml

# Reconcile HelmRelease
flux reconcile hr opencost -n flux-system --with-source