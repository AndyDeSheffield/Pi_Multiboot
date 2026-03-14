#!/bin/bash

# Usage:
#   sudo ./detachimage.sh image.img

IMG="$1"

if [ -z "$IMG" ]; then
    echo "Usage: $0 <imagefile>"
    exit 1
fi

# Find loop device
LOOP=$(losetup -j "$IMG" | awk -F: '{print $1}')

if [ -z "$LOOP" ]; then
    echo "No loop device found for $IMG"
    exit 0
fi

echo "Found loop device: $LOOP"

# Unmount any mount points
for MP in /mnt/image*; do
    if mount | grep -q "on $MP "; then
        echo "Unmounting $MP..."
        umount "$MP" || echo "Warning: failed to unmount $MP"
    fi
done

# Detach loop
echo "Detaching $LOOP..."
losetup -d "$LOOP" || echo "Warning: failed to detach loop"

echo "Done."
