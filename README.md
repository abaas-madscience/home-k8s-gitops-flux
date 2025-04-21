# 🚀 Homelab Kubernetes Cluster from Scratch

Welcome to the **Homelab K8S Cluster** repository! This guide walks you through setting up a Upstream Native Kubernetes cluster from scratch using Arch Linux, containerd, and Cilium for networking. The setup is tailored for a homelab environment with GitOps principles powered by Flux.

---

## 📋 Prerequisites

Before starting, ensure the following:

- 🖥️ **Minimal Base Arch Images** installed on all nodes.
- 🔄 **IP Forwarding** enabled on all boxes.
- 🔥 **Firewall Disabled** (IPTables will be managed by Kubernetes).
- ❌ **Swap Disabled** (Kubernetes requires swap to be off).

### 🛠️ Required Kernel Modules

Load the following kernel modules:

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

Persist the modules by adding them to `/etc/modules-load.d/k8s.conf`:

```bash
echo -e "br_netfilter\noverlay" | sudo tee /etc/modules-load.d/k8s.conf
```

The `br_netfilter` module allows iptables to see bridged traffic, which is crucial for Kubernetes networking, especially for components like kube-proxy, CNI plugins, and service routing.

---

## 🔧 System Configuration

Edit `/etc/sysctl.d/k8s.conf` to enable required sysctl parameters:

```bash
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
```

Apply the changes:

```bash
sudo sysctl --system
```

---

## 🐳 Install Container Runtime

Install `containerd`:

```bash
sudo pacman -S containerd
```

Create a baseline configuration:

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
```

Enable and start the service:

```bash
sudo systemctl enable --now containerd
```

Test the service:

```bash
sudo pacman -S crictl
sudo crictl info
```

---

## ⚙️ Configure Kubelet

Kubelet is the node agent that manages pod lifecycles. It is used by `kubeadm init` to initialize the cluster and spawn the control node. Kubelet:

- Watches the API server.
- Runs containers via the runtime.
- Monitors pod health and status.
- Handles lifecycle tasks like pulling images, mounting volumes, and applying cgroups.
- Applies the desired state from the control plane to the local node.

---

## 🛠️ iSCSI Configuration

Prepare the nodes to handle iSCSI targets. Add a method to deploy iSCSI and start the services via Ansible.

---

## 🌐 CNI (Container Network Interface)

For networking, we use **Cilium** due to its eBPF-based kernel security and identity-based security features. Ensure your kernel version is 5.15+ (Arch Linux is at 6.14 at the time of writing).

---

## 🏗️ Initialize the Cluster

Create the `kubeadm` configuration file, I have one in yamls


Initialize the cluster:
We ignore port 10250 since we know it's a bare machine.
We also remove kube-proxy in favor of Cilium

```bash
sudo kubeadm init --config kubeinit.yaml --ignore-preflight-errors=Port-10250   --skip-phases=addon/kube-proxy

```

Set up `kubectl`:

```bash
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
```

---

## 🌐 Install Cilium

Install Cilium using Helm:
We remove kubeproxy altogether.

```bash
helm install cilium cilium/cilium \
  --version 1.17.3 \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=<control-plane-ip> \
  --set k8sServicePort=6443 \
  --set ipam.mode=kubernetes \
  --set cluster.name=archcore \
  --set cluster.id=1 \
```

Check Cilium status:

```bash
kubectl -n kube-system exec ds/cilium -- cilium status
```

If CoreDNS gets stuck, restart `containerd` and `kubelet`.

---

## 🌀 Bootstrap Flux

Install Flux:

```bash
yay -S flux-bin
```

Bootstrap Flux with GitHub:

```bash
flux bootstrap github \
  --owner=abaas-madscience \
  --repository=home-k8s-gitops-flux \
  --branch=main \
  --path=clusters/lab \
  --personal
```

Enter your GitHub PAT and watch the pods come online.

---

## 🛠️ Add Nodes to the Cluster

Generate the join command:

```bash
kubeadm token create --print-join-command
```

Run the join command on the new nodes:

```bash
sudo kubeadm join <control-plane-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

Example:

```bash
sudo kubeadm join 192.168.178.7:6443 --token axzcqr.s85tyjrfjg1y8qak --discovery-token-ca-cert-hash sha256:1d4e93e09e8d4506f6669218ecc1ecdc4afa50ece43dfbbbf0de1d5097a434ad
```
You can check the output:

```bash
kubectl get nodes -o wide
```

---
*Check for ARP on a host*
sudo tcpdump -i enp1s0 -n arp
---

---
## Check for Endpointd
kubectl get endpoints cilium-ingress-echo-ingress

NAME                          ENDPOINTS              AGE
cilium-ingress-echo-ingress   192.192.192.192:9999   14s

---

## 💾 Storage

Storage has been moved into Flux with 3 nodes. Configure it to use your nodes.

---

## 🧪 Future Enhancements

- ✨ Build a CiliumPolicyWatcher operator:
  - Scans all namespaces
  - Identifies pods not covered by any CiliumNetworkPolicy
  - Emits alerts or applies quarantine policy
