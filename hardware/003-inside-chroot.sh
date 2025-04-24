#!/bin/bash
set -e

# Set DISK
DISK=$(lsblk -ndo PKNAME $(findmnt -no SOURCE /) | head -n1)


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
echo "127.0.1.1 k8s-node.localdomain k8s-node" >> /etc/hosts

# Network setup (systemd-networkd example)
mkdir -p /etc/systemd/network
cat <<EOF > /etc/systemd/network/20-static.network
[Match]
Name=eth0

[Network]
Address=192.168.178.101/24
Gateway=192.168.178.1
DNS=192.168.178.1
EOF

systemctl enable systemd-networkd
systemctl enable systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Initramfs (if custom modules later)
mkinitcpio -P

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

# Pacman
# Install required packages
pacman -Sy --noconfirm \
  containerd \
  kubelet kubeadm kubectl \
  iptables-nft \
  ebtables \
  ethtool \
  socat \
  conntrack-tools \
  iproute2 \
  crictl \
  bash-completion \
  linux-headers

# Enable containerd
systemctl enable containerd

# Enable kubelet (fails on first boot, ignore)
systemctl enable kubelet

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

