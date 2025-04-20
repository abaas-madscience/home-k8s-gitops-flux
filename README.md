** Homelab K8S cluster from scratch **

Prerequisites:
Minimal Base Arch Images
IP Forwarding on all boxes
IP Firewall OFF
Swap OFF

loaded modules:
overlay
br_netfilter

sudo modprobe overlay
sudo modprobe br_netfilter

echo -e "br_netfilter\noverlay" > /etc/modules-load.d/k8s.conf

br_netfilter is a kernel module that allows iptables to see bridged traffic—which is crucial for Kubernetes networking, especially for things like kube-proxy, CNI plugins, and service routing.

Without it, things like iptables -m physdev or inter-pod traffic across bridges might silently fail or behave weirdly.

# Edit /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1

# Install container runtime
sudo pacman -S containerd

# Create a safe baseline config
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Start the service
sudo systemctl enable --now containerd

# Test the service
sudo pacman -S crictl
sudo crictl info

=========================================
= Above steps have been moved to ansbible
=========================================

Now we can configure kubelet which is a node agent and managed pod lifecycles
When you run kubeadm init to init the cluster it uses kubelet to spawn the control node
kubelet watches API server
 - runs containers via the runtime
 - monitors pod health and status
 - handles lifecycle - pulls image -> mounts volumes -> applies cgroups
 - applies the desired state from the control plane to the local node
 Kubelet is not an orchestrator, it executes orders from the control plane using local resources

# iScsci : Prepare the nodes to handle iScsi targets
<todo> add to ansible a way to drop iSCSI unto the nodes and start the services


# CNI
==========================================
= CNI
==========================================
I had the choice of Flannel vs Calico vs Cilium
Since I am deeply interested in eBPF and kernel based security, 
Also about identity based security I chose Cilium

For Cilium to work properly we need to be at kernel 5.15+ which Arch is at 6.14 at time of writing


================
= Now we can init the cluster
================
```
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  name: archcore-control
  criSocket: unix:///run/containerd/containerd.sock

---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: "1.32.1"  # <- My version
controlPlaneEndpoint: "archcore-control.lab.local:6443"
networking:
  podSubnet: "10.10.0.0/16"   # <- Pod network
  serviceSubnet: "10.96.0.0/12"
  dnsDomain: "cluster.local"
```
##
This broke and i ran the config migrate command, the new file is in yamls/kubeinit.yaml

Step 1 stop kubelet
systemctl stop kubelet.service

Then sudo kubeadm init --config kubeinit.yaml --ignore-preflight-errors=Port-10250
since it's bare we know kubelet is running on 10250

Then

```
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
```


Now we can start with CNI, our networking cilium

########################
# helm search repo cilium/cilium --versions | head -n 5
####

Grab the latest version

```
helm install cilium cilium/cilium \
  --version 1.17.3 \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=192.168.178.7 \
  --set k8sServicePort=6443 \
  --set ipam.mode=kubernetes \
  --set cluster.name=archcore \
  --set cluster.id=1
```

DEBUG
kubectl -n kube-system exec ds/cilium -- cilium status

!! After this coreDNS might get stuck, just restart containerd and then kubelet !!

System is up by now and we should see everything ready.

[oscar@archcore-control ~]$ kubectl get nodes
NAME               STATUS   ROLES           AGE   VERSION
archcore-control   Ready    control-plane   43m   v1.32.1

Now bootstrap flux

```
yay -S flux-bin

```

```
flux bootstrap github \
  --owner=abaas-madscience \
  --repository=home-k8s-gitops-flux \
  --branch=main \
  --path=clusters/lab \
  --personal
```

Slap in the Github PAT and watch the pods come online

# Check Cilium status
```bash
kubectl -n kube-system exec -ti ds/cilium -- cilium status
```