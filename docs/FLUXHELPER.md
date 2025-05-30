kubectl get kustomizations -A


kubectl delete kustomization <name> -n flux-system

kubectl rollout restart deployment -n flux-system


flux reconcile source git flux-system --with-source


flux reconcile kustomization flux-system --with-source
flux reconcile kustomization infra-cilium --with-source


# Gateway
➜ k describe gateway -n hypercube-test hypercube-gateway