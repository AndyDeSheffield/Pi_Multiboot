#!/bin/bash
set -euo pipefail

# Usage: ./restore_admin_image.sh /mnt/realimages

if [ $# -ne 1 ]; then
    echo "Usage: $0 <restore-target-directory>"
    exit 1
fi

TARGET="$1"
ARCHIVE="Multiboot_Admin_os.tar.gz"

# Check archive exists in current directory
if [ ! -f "$ARCHIVE" ]; then
    echo "Error: $ARCHIVE not found in current directory"
    exit 1
fi

# Check target exists and is a directory
if [ ! -d "$TARGET" ]; then
    echo "Error: Target directory '$TARGET' does not exist"
    exit 1
fi

echo "Restoring $ARCHIVE into $TARGET ..."
sudo tar -xzf "$ARCHIVE" -C "$TARGET"

echo "Restore complete."
echo "Insert the contents of Grub_MultiBoot_Admin_pi4.cfg or Grub_MultiBoot_Admin_pi3b.cfg into grub"