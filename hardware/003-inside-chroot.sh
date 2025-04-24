#!/bin/bash
set -e

# Set DISK
#DISK=$(lsblk -ndo PKNAME $(findmnt -no SOURCE /) | head -n1)
DISK="/dev/vda"

read -p "Enter static IP (e.g. 192.168.178.101): " STATIC_IP
read -p "Enter gateway (e.g. 192.168.178.1): " GATEWAY
read -p "Enter DNS (e.g. 192.168.178.1): " DNS
read -p "Enter hostname: " NODE_HOSTNAME


# Locale & Time
ln -sf /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname
echo "k8s-node" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $NODE_HOSTNAME.lab.local $NODE_HOSTNAME" >> /etc/hosts

# Network setup (systemd-networkd example)
mkdir -p /etc/systemd/network
cat <<EOF > /etc/systemd/network/20-static.network
[Match]
Name=enp1s0

[Network]
Address=$STATIC_IP/24
Gateway=$GATEWAY
DNS=$DNS  
EOF

systemctl enable systemd-networkd
systemctl enable systemd-resolved
#ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Systemd bootloader
bootctl --path=/boot install
cat <<EOF > /boot/loader/loader.conf
default arch
timeout 3
editor no
EOF

cat <<EOF > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=$(blkid -s UUID -o value ${DISK}2) rw
EOF

echo "📍 Reached pacman"

# Pacman
# Install required packages
pacman -Syu --noconfirm


# Install required packages
if ! pacman -Sy --noconfirm \
  openssh \
  containerd \
  ethtool \
  socat \
  xfsprogs \
  conntrack-tools \
  crictl \
  bash-completion \
  linux-headers; then
    echo "Pacman installation failed with error code $?"
    exit 1
fi
echo "📍 passed pacman"

# Enable containerd
systemctl enable containerd

# Enable kubelet (fails on first boot, ignore)
systemctl enable kubelet

# Enable SSH
systemctl enable sshd

echo "📍 Set Kernel parameters"

# Kernel params for eBPF + forwarding
cat <<EOF > /etc/sysctl.d/99-k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Load necessary modules
cat <<EOF > /etc/modules-load.d/k8s.conf
br_netfilter
overlay
EOF

# Persist module loading
mkdir -p /etc/sysctl.d
echo "fs.inotify.max_user_watches=524288" >> /etc/sysctl.d/98-inotify.conf

# Create user
useradd -m -G wheel oscar
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/oscar

# Set network time sync
timedatectl set-ntp true

# Install yay (AUR helper)
cd /home/oscar
sudo -u oscar git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u oscar makepkg -si --noconfirm
cd ..
rm -rf yay

sudo -u oscar yay -S --noconfirm cilium-cli hubble-ui-bin

# Set some BASH aliases
cat << 'EOF' >> /home/oscar/.bashrc

# Kubernetes alias
alias k='kubectl'
complete -F __start_kubectl k

# Cilium alias
alias c='cilium'
complete -C /usr/bin/cilium c

# Better PS1 for quick context switching
export PS1="[\u@\h \W \$(kubectl config current-context 2>/dev/null)]\$ "

EOF

chown oscar:oscar /home/oscar/.bashrc

# Set SSH Key

echo "🎉 Setup complete. You can now reboot into your new Arch node."

# Last step
mkinitcpio -P


#
#K8S_VERSION="v1.32.0"

#curl -LO https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl
#curl -LO https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubelet
#curl -LO https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubeadm

#chmod +x kube*
#mv kubelet kubeadm kubectl /usr/local/bin/