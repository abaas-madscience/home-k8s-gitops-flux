

# Show Memory and CPU Usage of Nodes
kubectl top nodes

# Rollout Restart anything
kubectl rollout restart -n kube-system ds/tetragon

### TALOS
talosctl -n 192.168.178.3 dashboard

## KIND CLUSTER
./cluster-builder.sh --name advanced --disable-cni --disable-kube-proxy

## CRDS
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml


# Then Cilium install with the following configuration:
cilium install \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=true \
  --set l2announcements.enabled=true \
  --set gatewayAPI.enabled=true \
  --set gatewayAPI.enableAlpn=true \
  --set gatewayAPI.enableAppProtocol=true

cilium hubble enable --ui

cilium hubble ui

