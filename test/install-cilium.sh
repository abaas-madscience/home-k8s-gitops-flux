!!! -> WRONG !kubectl apply -k "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.0.0"

helm upgrade --install cilium cilium/cilium \
  --version 1.17.3 \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=archcore-control.lab.local \
  --set k8sServicePort=6443 \
  --set l2announcements.enabled=true \
  --set l2announcements.interfaces[0]="enp1s0" \
  --set externalIPs.enabled=true \
  --set loadBalancerIPs.enabled=true \
  --set ciliumIngress.enabled=true \
  --set ciliumIngress.replicas=1 \
  --set operator.enabled=true \
  --set operator.manageCRDs=true \
  --set gatewayAPI.enabled=true \
  --set gatewayAPI.secretsNamespace.name=kube-system \
  --set gatewayAPI.secretsNamespace.create=false \
  --set gatewayAPI.secretsNamespace.sync=true

kubectl get gatewayclass -o yaml

kubectl -n kube-system rollout restart deploy/cilium-operator


READ THE DOCS !!!

kubectl get gatewayclass
