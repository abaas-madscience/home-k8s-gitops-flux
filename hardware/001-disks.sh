#!/bin/bash
set -e

DISK="/dev/vda"  # or /dev/sda or /dev/nvme0n1 — override as arg if you want
EFI_SIZE="512MiB"

# Wipe disk
sgdisk --zap-all "$DISK"

# Partition: EFI + Root
parted -s "$DISK" \
  mklabel gpt \
  mkpart ESP fat32 1MiB $EFI_SIZE \
  set 1 boot on \
  mkpart primary xfs $EFI_SIZE 100%

# Format
mkfs.fat -F32 "${DISK}1"
mkfs.xfs -f "${DISK}2"

# Mount
mount "${DISK}2" /mnt
mkdir -p /mnt/boot
mount "${DISK}1" /mnt/boot

bash /mnt/nfs/002-arch.sh
