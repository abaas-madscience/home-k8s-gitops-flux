## 🚀 TALOS ON BARE PLASTIC ##

### 🛠️ Prerequisites
Before starting, ensure you have the following:
- A Talos ucode image (downloadable from the Talos website).
- A USB drive with Ventoy installed.
- Access to the Talos console for setting static IP and hostname.

---

### 1️⃣ **Set Environment Variables**
Export the IP addresses of your control plane and nodes.

```bash
# Add these to your .zshrc or .bashrc for persistence
export CONTROL=192.168.178.3
export NODE1=192.168.178.4
export NODE2=192.168.178.5
```

---

### 2️⃣ **Prepare the Bootable USB**
1. Generate a ucode image from the Talos website.
2. Copy the image to your Ventoy USB drive.
3. Boot the target machines using the USB.

---

### 3️⃣ **Set Static IP and Hostname**
In the Talos console:
- Assign a static IP (use `/24` subnet).
- Set the hostname for each node.

---

### 4️⃣ **Generate Base Configuration**
Generate the Talos configuration with a custom patch file to disable the default CNI (Flannel) and KubeProxy.

```bash
talosctl gen config hypercube https://$CONTROL:6443 \
  --with-docs=false \
  --with-examples=false \
  --config-patch @patch.yaml
```

---

### 5️⃣ **Identify Disk Devices**
Find the disk devices for your control plane and nodes.

```bash
talosctl get disks --insecure -n $CONTROL
```

---

### 6️⃣ **Update Configuration**
Edit `controlplane.yaml`:
- Replace `installer: /dev/sda` with the correct disk device.
- Add the following line under the `clusters` section to allow scheduling on the control plane:

```yaml
allowSchedulingOnControlPlanes: true
```

---

### 7️⃣ **Apply Configuration**
Apply the configuration to the control plane.

```bash
talosctl apply-config -f controlplane.yaml -n $CONTROL --insecure
```

Wait for all phases to complete, then reboot the machine.

---

### 8️⃣ **Bootstrap the Cluster**
Bootstrap the cluster and monitor the console for progress.

```bash
talosctl --talosconfig ./talosconfig bootstrap -n $CONTROL -e $CONTROL
```

---

### 9️⃣ **Wait for Cluster Readiness**
Wait until the cluster is fully operational:
- Kubelet should be healthy and ready (green checkmark).

---

### 🔟 **Configure Talosctl**
Set up the Talos configuration.

```bash
export TALOSCONFIG=<path_to_talosconfig>
talosctl config endpoint $CONTROL
talosctl config node $CONTROL
```

---

### 1️⃣1️⃣ **Retrieve Kubeconfig**
Get the kubeconfig file and set it up for `kubectl`.

```bash
talosctl kubeconfig .
cp kubeconfig /home/oscar/.kube/config

# For zsh users
export KUBECONFIG=/home/oscar/.kube/config
```

---

### 1️⃣2️⃣ **Install Gateway API CRDs**
Install the required CRDs for Gateway API (check for the latest version).

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml
```

---

### 1️⃣3️⃣ **Install Cilium**
Install Cilium with the following configuration:

This removed kubeproxy and uses Cilium as the CNI.
L2 announcements are enabled for the gateway API.
This also sets the security context for the Cilium agent and cleanCiliumState.
This is important for the Cilium agent to work properly.
This also sets the cgroup host root to /sys/fs/cgroup, which is important for Cilium to work properly.
This also sets the kubeProxyReplacement to true, which is important for Cilium to work properly.
This also sets the k8sServiceHost and k8sServicePort to localhost and 7445, which is important for Cilium to work properly.
This also sets the gatewayAPI to true, which is important for Cilium to work properly.
This also sets the gatewayAPI.enableAlpn to true, which is important for Cilium to work properly.
This also sets the gatewayAPI.enableAppProtocol to true, which is important for Cilium to work properly.

```bash
cilium install \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=true \
  --set l2announcements.enabled=true \
  --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
  --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
  --set cgroup.autoMount.enabled=false \
  --set cgroup.hostRoot=/sys/fs/cgroup \
  --set k8sServiceHost=localhost \
  --set k8sServicePort=7445 \
  --set gatewayAPI.enabled=true \
  --set gatewayAPI.enableAlpn=true \
  --set gatewayAPI.enableAppProtocol=true
```

---

### 🎉 **Cluster is Ready**
Your Talos cluster with Cilium is now online and ready for use! TALOS ON BARE PLASTIC ##


### Add Node:

talosctl apply-config \
  --nodes <WORKER-IP> \
  --file worker.yaml \
  --talosconfig ./talosconfig \
  --insecure


kubectl label namespace infra-longhorn pod-security.kubernetes.io/enforce=privileged

  ## Add Flux


## Restart Cilium Operator
kubectl rollout restart deployment/cilium-operator -n kube-system

## Check Routes and gateways
kubectl get gateway,httproute -A -o custom-columns='KIND:kind,NAMESPACE:metadata.namespace,NAME:metadata.name,ADDR:status.addresses[*].value,CONDITION:status.conditions[-1].type,STATUS:status.conditions[-1].status,REASON:status.conditions[-1].reason'

## Check Resolutions
kubectl get httproute -A -o=jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{.status.parents[*].conditions[*].type}{"\t"}{.status.parents[*].conditions[*].status}{"\n"}{end}' | grep ResolvedRefs

## Traffic map
kubectl get httproute -A -o=jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{range .spec.parentRefs[*]}{.name}{"\t"}{end}{range .spec.hostnames[*]}{.}{"\t"}{end}{range .spec.rules[*].backendRefs[*]}{.name}{"\t"}{.port}{"\n"}{end}'

# Check a specific route
kubectl get httproute -n infra-longhorn longhorn-route -o yaml | grep -A10 status:
  
## TODO
Create Servicemonitors
Checkout: #1 — kube-graph (CLI tool, graphviz output)
go install github.com/henderiw/kube-graph/cmd/kube-graph@latest

kube-graph > cluster-topology.dot
dot -Tpng cluster-topology.dot -o cluster-topology.png

#2 topology-viewer
kubectl apply -f https://raw.githubusercontent.com/weaveworks-plugins/k8s-topology-viewer/main/deploy/k8s-topology-viewer.yaml
Expose it via HTTPRoute (optional)
Or just kubectl port-forward to localhost.

Then open:
http://localhost:8080


# Search helm releases
helm search repo vm/victoria-metrics-single -l | head -n 5

# Find Tainted nodes
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.taints[*]}{.key}{"="}{.value}{" "}{end}{"\n"}{end}'

# Check logs
kubectl get events -n monitoring --sort-by='.lastTimestamp' | tail -20

10m         Warning   FailedCreate             daemonset/monitoring-infra-node-exporter-prometheus-node-exporter                          Error creating: pods "monitoring-infra-node-exporter-prometheus-node-exporter-lwdsm" is forbidden: violates PodSecurity "baseline:latest": host namespaces (hostNetwork=true, hostPID=true), hostPath volumes (volumes "proc", "sys"), hostPort (container "node-exporter" uses hostPort 9100)