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
export TALOSCONFIG=/home/oscar/.config/hypercube/talosconfig
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

```bash
cilium install \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=true \
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
