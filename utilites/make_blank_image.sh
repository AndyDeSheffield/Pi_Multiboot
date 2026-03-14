#!/bin/bash

# Usage:
#   sudo ./makeimage.sh image.img 400M
#   sudo ./makeimage.sh -f image.img 4G

FORCE=0

# Parse optional -f
if [ "$1" = "-f" ]; then
    FORCE=1
    shift
fi

IMG="$1"
SIZE="$2"

if [ -z "$IMG" ] || [ -z "$SIZE" ]; then
    echo "Usage: $0 [-f] <imagefile> <size>"
    echo "Examples: 400M, 4G, 1024K"
    exit 1
fi

# Check if file exists
if [ -e "$IMG" ] && [ $FORCE -eq 0 ]; then
    echo "File $IMG already exists. Replace? (Y/N)"
    read -r ANSWER
    if [ "$ANSWER" != "Y" ]; then
        echo "Aborting."
        exit 1
    fi
fi

echo "Creating image $IMG of size $SIZE..."
truncate -s "$SIZE" "$IMG"
echo "Done."
