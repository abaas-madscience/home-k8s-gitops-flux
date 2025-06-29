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

# DELETE all completed pods
kubectl get pods --all-namespaces | grep -E 'Completed' | awk '{print $2 " -n " $1}' | xargs -L1 kubectl delete pod


kubectl get pods --all-namespaces | grep -E 'ContainerStatusUnknown' | awk '{print $2 " -n " $1}' | xargs -L1 kubectl delete pod


# CHECK TO SEE IF The correct helmrelease is applied
kubectl get helmrelease opencost -n flux-system -o yaml

# Reconcile HelmRelease
flux reconcile hr opencost -n flux-system --with-source


# Check K8S event
kubectl get events -n infra-falco --sort-by='.lastTimestamp'

# Check all events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' --field-selector type!=Normal

# Check API Server logs
kubectl logs -n kube-system -l component=kube-apiserver --tail 50 --timestamps
# Or to follow:
kubectl logs -n kube-system -l component=kube-apiserver -f

# Check Controller Manager logs
kubectl logs -n kube-system -l component=kube-controller-manager --tail 50 --timestamps

# Check Scheduler logs
kubectl logs -n kube-system -l component=kube-scheduler --tail 50 --timestamps

# Check Cilium logs
kubectl logs -n kube-system -l k8s-app=cilium --tail 50 --timestamps # For cilium-agent pods

# Check Cilium Operator logs
kubectl get pods -n kube-system -l k8s-app=cilium

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns --tail 50 --timestamps