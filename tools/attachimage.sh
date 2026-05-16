#!/bin/bash

set -euo pipefail

#
# Usage:
#   ./attachimage.sh image.img
#   ./attachimage.sh -m image.img
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

MOUNT=0

if [[ "${1:-}" == "-m" ]]; then
    MOUNT=1
    shift
fi

IMG="${1:-}"

if [[ -z "$IMG" ]]; then
    echo "Usage: $0 [-m] <imagefile>"
    exit 1
fi

IMG=$(readlink -f "$IMG")

if [[ ! -f "$IMG" ]]; then
    echo "Image file not found: $IMG"
    exit 1
fi

echo "Attaching image:"
echo "  $IMG"

LOOP=$(losetup --find --show --partscan "$IMG")

if [[ -z "$LOOP" ]]; then
    echo "Failed to create loop device."
    exit 1
fi

echo
echo "Attached loop device:"
echo "  $LOOP"

if [[ "$MOUNT" -eq 0 ]]; then
    exit 0
fi

echo
echo "Scanning for partitions..."

PARTITIONS=()

for P in "${LOOP}"p*; do
    [[ -e "$P" ]] || continue
    PARTITIONS+=("$P")
done

if [[ ${#PARTITIONS[@]} -eq 0 ]]; then
    PARTITIONS=("$LOOP")
fi

INDEX=1

for DEV in "${PARTITIONS[@]}"; do

    MP="/mnt/$(basename "$LOOP")p$INDEX"

    mkdir -p "$MP"

    echo
    echo "Mounting:"
    echo "  Device : $DEV"
    echo "  Mount  : $MP"

    if mount "$DEV" "$MP"; then
        echo "Mounted successfully"
    else
        echo "WARNING: mount failed for $DEV"
        rmdir "$MP" 2>/dev/null || true
    fi

    INDEX=$((INDEX + 1))
done

echo
echo "Done."
