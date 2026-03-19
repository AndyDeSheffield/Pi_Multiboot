#!/bin/bash

# Usage:
#   sudo ./attachimage.sh image.img
#   sudo ./attachimage.sh -m /path/to/image.img

MOUNT=0

if [ "$1" = "-m" ]; then
    MOUNT=1
    shift
fi

IMG="$1"

if [ -z "$IMG" ]; then
    echo "Usage: $0 [-m] <imagefile>"
    exit 1
fi

# Create loop device
LOOP=$(losetup --show -fP "$IMG")
if [ -z "$LOOP" ]; then
    echo "Failed to attach loop device."
    exit 1
fi

echo "Attached to loop device: $LOOP"

# If no mounting requested, exit here
if [ $MOUNT -eq 0 ]; then
    exit 0
fi

# Check for partitions
PARTS=$(ls ${LOOP}p* 2>/dev/null | wc -l)

if [ "$PARTS" -eq 0 ]; then
    # No partitions → mount whole image
    mkdir -p /mnt/image1
    mount "$LOOP" /mnt/image1
    echo "Mounted $LOOP at /mnt/image1"
else
    # Mount each partition
    i=1
    for P in ${LOOP}p*; do
        MP="/mnt/image$i"
        mkdir -p "$MP"
        mount "$P" "$MP"
        echo "Mounted $P at $MP"
        i=$((i+1))
    done
fi
