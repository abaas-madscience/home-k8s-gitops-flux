#!/bin/bash
set -e

setfont ter-v32n

# Mount the NFS installer
mkdir /mnt/nfs
mount -t nfs 192.168.178.2:/srv/nfs/installer /mnt/nfs

# Run your scripts
