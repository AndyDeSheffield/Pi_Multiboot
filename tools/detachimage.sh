#!/bin/bash

set -euo pipefail

#
# Usage:
#   ./detachimage.sh image.img
#

self_elevate() {
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            exec sudo "$0" "$@"
        else
            exec su -c "'$0' $*"
        fi
    fi
}

self_elevate "$@"

IMG="${1:-}"

if [[ -z "$IMG" ]]; then
    echo "Usage: $0 <imagefile>"
    exit 1
fi

IMG=$(readlink -f "$IMG")

if [[ ! -f "$IMG" ]]; then
    echo "Image file not found:"
    echo "  $IMG"
    exit 1
fi

LOOP=$(losetup -j "$IMG" | awk -F: 'NR==1 {print $1}')

if [[ -z "$LOOP" ]]; then
    echo "No loop device associated with:"
    echo "  $IMG"
    exit 0
fi

echo "Found loop device:"
echo "  $LOOP"

echo
echo "Looking for mounted filesystems..."

MOUNTS=$(mount | awk -v loop="$LOOP" '
    $1 ~ "^"loop {
        print $3
    }
')

if [[ -n "$MOUNTS" ]]; then

    echo "$MOUNTS" | tac | while read -r MP; do

        [[ -z "$MP" ]] && continue

        echo
        echo "Unmounting:"
        echo "  $MP"

        if umount "$MP"; then
            echo "Unmounted normally."
        else
            echo "Normal unmount failed."

            echo "Trying forced unmount..."
            if umount -f "$MP" 2>/dev/null; then
                echo "Forced unmount succeeded."
            else
                echo "Forced unmount failed."

                echo "Trying lazy unmount..."
                if umount -l "$MP"; then
                    echo "Lazy unmount succeeded."
                else
                    echo "ERROR: Could not unmount $MP"
                fi
            fi
        fi

        rmdir "$MP" 2>/dev/null || true
    done

else
    echo "No mounted partitions found."
fi

echo
echo "Detaching loop device..."

if losetup -d "$LOOP"; then
    echo "Loop detached successfully."
else
    echo "Initial detach failed."

    echo "Retrying with partition cleanup..."

    partx -d "$LOOP" 2>/dev/null || true
    kpartx -d "$LOOP" 2>/dev/null || true

    sleep 1

    if losetup -d "$LOOP"; then
        echo "Loop detached successfully after cleanup."
    else
        echo
        echo "ERROR: Failed to detach loop device."
        echo
        echo "Processes still using it:"
        fuser -vm "$LOOP" || true
        exit 1
    fi
fi

echo
echo "Done."
