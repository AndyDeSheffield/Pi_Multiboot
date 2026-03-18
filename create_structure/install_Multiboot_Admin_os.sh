#!/bin/bash
set -euo pipefail
#update lines below for each new version
ARCHIVE="MultiBoot_Admin_os_v0.5.tar.gz"
RELEASE="Version_0.5_alpha"

# Usage: example ./restore_admin_image.sh sdb

if [ $# -ne 1 ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 target disk - example $0 sdb (Do not specify a partition) .Use $0 -l to list disks"
    exit 1
fi

if [ "$1" = "-l" ]; then
    echo "listing all devices"
        lsblk --tree --filter 'NAME =~ "^sd"' -o NAME,VENDOR,LABEL,SIZE,MOUNTPOINTS,RM
        exit 0
fi
#Identify the Images partition
TARGET="/dev/$(lsblk -nr /dev/$1  -o NAME,LABEL |awk '$2=="IMAGES"{print $1}')"
if [ -z "$TARGET" ]; then
    echo "No IMAGES partition found on /dev/$0"
    exit 1
fi
echo "IMAGES partition identified as $TARGET"

# Mount the target partition and restore the Admin disk archive
echo "Creating mountpoint and mounting $TARGET"
sudo mkdir -p /mnt/realimages
sudo mount $TARGET /mnt/realimages
echo "Fetching Admin image $ARCHIVE"

CURRENTDIR=$PWD
cd /mnt/realimages/staging
sudo wget "https://github.com/AndyDeSheffield/Pi_Multiboot/releases/download/$RELEASE/$ARCHIVE"
echo "Restoring $ARCHIVE into /mnt/realimages"
sudo tar -xzf "$ARCHIVE" -C /mnt/realimages
sync
echo "Restore complete. Unmounting and removing mount directory"
cd $CURRENTDIR
sudo umount /mnt/realimages
sudo rmdir /mnt/realimages