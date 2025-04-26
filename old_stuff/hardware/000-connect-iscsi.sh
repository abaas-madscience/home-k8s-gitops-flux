#!/bin/bash
set -e

setfont ter-v32n

# Mount the NFS installer
mkdir /mnt/nfs
mount -t nfs 192.168.178.2:/ /mnt/nfs

# Run your scripts


# Help for NFS
#sudo exportfs -ua
#sudo systemctl restart nfs-server
#sudo systemctl restart rpcbind
