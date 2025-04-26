# Base install (clean and valid)
pacstrap -K /mnt base linux linux-firmware vim sudo

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Copy setup script into chroot
cp 003-inside-chroot.sh /mnt/root/setup-chroot.sh
chmod +x /mnt/root/setup-chroot.sh

# Chroot into system and run the setup
arch-chroot /mnt /root/setup-chroot.sh
