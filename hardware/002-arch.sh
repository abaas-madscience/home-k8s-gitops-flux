# Base install
pacstrap -K /mnt base linux linux-firmware vim sudo networkd-dispatcher systemd-boot systemd-resolved

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Copy setup script into chroot
cp 003-inside-root.sh /mnt/root/setup-chroot.sh
chmod +x /mnt/root/setup-chroot.sh

# Chroot into system
arch-chroot /mnt /root/setup-chroot.sh
