#!/bin/bash
set -euo pipefail
#update lines below for each new version
ARCHIVE="MultiBoot_Admin_os.tar.gz"
RELEASE="latest"

# Usage: example ./restore_admin_image.sh /dev/sdb
if [ $# = 1 ] && [ "$1" = "-l" ]; then
    echo "listing all devices"
    lsblk --tree -o NAME,VENDOR,LABEL,SIZE,MOUNTPOINTS,RM         | grep --color=never -E '(^sd|[├└]─sd)'
    exit 0
fi

if [ $# -ne 1 ] || [ "$1" = "-h" ] || [ "${1:0:5}" != "/dev/" ]; then
    echo "*************************************************"
    echo "Usage: $0 /dev/target_disk"
    echo "Example $0 /dev/sdb (Do not specify a partition)."
    echo "Use $0 -l to list disks"
    echo "*************************************************"
    exit 1
fi


#Identify the Images partition
TARGET="$(lsblk -nr $1  -o NAME,LABEL |awk '$2=="IMAGES"{print $1}')"
if [ -z "$TARGET" ]; then
    echo "No IMAGES partition found on $1"
    exit 1
fi
TARGET="/dev/$TARGET"
echo "IMAGES partition identified as $TARGET"

# Mount the target partition and restore the Admin disk archive
echo "Creating mountpoint and mounting $TARGET as /mnt/realimages"
sudo mkdir -p /mnt/realimages
sudo mount $TARGET /mnt/realimages
echo "Fetching Admin image $ARCHIVE -> /mnt/realimages/staging/"
sleep 3
CURRENTDIR=$PWD
sudo mkdir -p /mnt/realimages/staging
cd /mnt/realimages/staging
sudo wget -q --show-progress "https://github.com/AndyDeSheffield/Pi_Multiboot/releases/download/$RELEASE/$ARCHIVE"
echo "Restoring $ARCHIVE into /mnt/realimages"
echo "This will take a long time even after the progress dots stop. Do not cancel"
sudo tar -xzf  "$ARCHIVE" -C /mnt/realimages --checkpoint=.5000
sync
echo "Restore complete. Unmounting and removing mount directory"
cd $CURRENTDIR
sudo umount /mnt/realimages
sudo rmdir /mnt/realimages
