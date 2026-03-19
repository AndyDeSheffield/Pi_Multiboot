#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
#  ROOT CHECK (only used before destructive actions)
# ------------------------------------------------------------
require_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "ERROR: This operation requires root."
        echo "Please re-run with sudo."
        exit 1
    fi
}

# ------------------------------------------------------------
#  DEFAULTS
# ------------------------------------------------------------
BOOT_REQ=0
SYSTEM_REQ=0
IMAGES_REQ=0

BOOT_SIZE="300M"
SYSTEM_SIZE="2G"
IMAGES_SIZE=""   # default = rest of disk

TARGET=""
MODEL=""
DRYRUN=0

# ------------------------------------------------------------
#  USAGE
# ------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  -l                List removable devices only
  -h                Show this help
  -n                Dry-run mode (no sudo required)

  -t=<device>       Target removable device (e.g. -t=/dev/sdb)

  -m=<model>        Model selector (e.g. pi3b, pi4, pi5)
                    Boot tarball becomes: boot<model>.tar.gz

  -b                Create BOOTPIn partition (default 300M) eg BOOTPI4
  -b=<size>         Create BOOTPIn with custom size

  -s                Create SYSTEM partition (default 2G)
  -s=<size>         Create SYSTEM with custom size

  -i                Create IMAGES partition (default: rest of disk)
  -i=<size>         Create IMAGES with custom size

Examples:
  $0 -l
  $0 -t=/dev/sdb -b -s -i
  $0 -t=/dev/sdb -b=200M -s=3G -i -m=pi4
EOF
}

# ------------------------------------------------------------
#  LIST REMOVABLE DEVICES
# ------------------------------------------------------------
list_removable() {
    echo "Removable devices:"
    lsblk -o NAME,MODEL,SIZE,RM,TYPE | grep "disk"
}

# ------------------------------------------------------------
#  ARGUMENT PARSING (strict = syntax)
# ------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -l) list_removable; exit 0 ;;
        -h) usage; exit 0 ;;
        -n) DRYRUN=1; shift ;;

        -t=*)
            TARGET="${1#*=}"
            shift
            ;;

        -m=*)
            MODEL="${1#*=}"
            shift
            ;;

        -b)
            BOOT_REQ=1
            shift
            ;;
        -b=*)
            BOOT_REQ=1
            BOOT_SIZE="${1#*=}"
            shift
            ;;

        -s)
            SYSTEM_REQ=1
            shift
            ;;
        -s=*)
            SYSTEM_REQ=1
            SYSTEM_SIZE="${1#*=}"
            shift
            ;;

        -i)
            IMAGES_REQ=1
            shift
            ;;
        -i=*)
            IMAGES_REQ=1
            IMAGES_SIZE="${1#*=}"
            shift
            ;;

        *)
            echo "Unknown or invalid option: $1"
            echo "Remember: -t must be used as -t=/dev/sdx"
            usage
            exit 1
            ;;
    esac
done

# ------------------------------------------------------------
#  VALIDATION
# ------------------------------------------------------------
if [ -z "$TARGET" ]; then
    echo "ERROR: -t=<device> is required unless using -l or -h."
    exit 1
fi

if [ ! -b "$TARGET" ]; then
    echo "ERROR: $TARGET is not a block device."
    exit 1
fi

if [ "$BOOT_REQ" -eq 0 ] && [ "$SYSTEM_REQ" -eq 0 ] && [ "$IMAGES_REQ" -eq 0 ]; then
    echo "ERROR: No partitions requested. Use -b, -s, or -i."
    exit 1
fi

# ------------------------------------------------------------
#  REMOVABLE DEVICE CHECK
# ------------------------------------------------------------
DEVNAME=$(basename "$TARGET")
REMOVABLE=$(cat "/sys/block/$DEVNAME/removable")

if [ "$REMOVABLE" -ne 1 ]; then
    echo "ERROR: $TARGET is NOT a removable device. Aborting."
    exit 1
fi

# ------------------------------------------------------------
#  MOUNTED PARTITION CHECK (dry-run skips prompt)
# ------------------------------------------------------------
check_mounted() {
    local dev="$1"

    local mounted
    mounted=$(lsblk -nrpo MOUNTPOINT "$dev" | grep -v '^$' || true)

    if [ -z "$mounted" ]; then
        return 0
    fi

    local first_mount
    first_mount=$(echo "$mounted" | head -n 1)

    echo "WARNING: Device $dev has mounted partitions."
    echo "First mountpoint detected: $first_mount"

    if [ "$DRYRUN" -eq 1 ]; then
        echo "Dry-run mode: skipping unmount prompt."
        return 0
    fi

    echo "If you continue, ALL partitions on this device will be unmounted and the disk will be wiped."
    read -r -p "Continue? (yes/no): " ans

    if [ "$ans" != "yes" ]; then
        echo "Aborting."
        exit 1
    fi

    echo "Unmounting all partitions on $dev..."
    for p in $(lsblk -nrpo NAME "$dev"); do
        umount "$p" 2>/dev/null || true
    done
}

check_mounted "$TARGET"

# ------------------------------------------------------------
#  COMPUTE PARTITION LAYOUT
# ------------------------------------------------------------
START="1MiB"
CURRENT_START="$START"

LAYOUT=""

if [ "$BOOT_REQ" -eq 1 ]; then
    BOOT_END="$BOOT_SIZE"
    LAYOUT+="BOOT ($BOOT_SIZE)\n"
fi

if [ "$SYSTEM_REQ" -eq 1 ]; then
    SYSTEM_END="$SYSTEM_SIZE"
    LAYOUT+="SYSTEM ($SYSTEM_SIZE)\n"
fi

if [ "$IMAGES_REQ" -eq 1 ]; then
    if [ -n "$IMAGES_SIZE" ]; then
        IMAGES_END="$IMAGES_SIZE"
        LAYOUT+="IMAGES ($IMAGES_SIZE)\n"
    else
        IMAGES_END="100%"
        LAYOUT+="IMAGES (rest of disk)\n"
    fi
fi

# ------------------------------------------------------------
#  DRY RUN SUMMARY (no sudo required)
# ------------------------------------------------------------
echo "Target device: $TARGET"
echo -e "Requested layout:\n$LAYOUT"

if [ -n "$MODEL" ]; then
    echo "Boot model: $MODEL"
    echo "Boot tarball: boot${MODEL}.tar.gz"
else
    echo "Boot tarball: boot.tar.gz"
fi

if [ "$DRYRUN" -eq 1 ]; then
    echo "Dry-run mode: no changes will be made."
    exit 0
fi

# ------------------------------------------------------------
#  FINAL CONFIRMATION (real run only)
# ------------------------------------------------------------
echo "This will WIPE $TARGET and create the partitions above."
read -r -p "Type 'yes' to continue: " final

if [ "$final" != "yes" ]; then
    echo "Aborting."
    exit 1
fi

# Require root now
require_root

# ------------------------------------------------------------
#  WIPE + PARTITION
# ------------------------------------------------------------
echo "Wiping partition table..."
parted -s "$TARGET" mklabel gpt

CURRENT_START="$START"

if [ "$BOOT_REQ" -eq 1 ]; then
    parted -s "$TARGET" mkpart REALBOOT fat32 "$CURRENT_START" "$BOOT_END"
    CURRENT_START="$BOOT_END"
fi

if [ "$SYSTEM_REQ" -eq 1 ]; then
    parted -s "$TARGET" mkpart SYSTEM ext4 "$CURRENT_START" "$SYSTEM_END"
    CURRENT_START="$SYSTEM_END"
fi

if [ "$IMAGES_REQ" -eq 1 ]; then
    parted -s "$TARGET" mkpart IMAGES ext4 "$CURRENT_START" "$IMAGES_END"
fi

parted -s "$TARGET" print

# ------------------------------------------------------------
#  FORMAT FILESYSTEMS
# ------------------------------------------------------------
PARTNUM=1

mkfs_safe() {
    require_root
    "$@"
}

if [ "$BOOT_REQ" -eq 1 ]; then
    mkfs_safe mkfs.vfat -F32 -n "BOOT${MODEL:0:3}" "${TARGET}${PARTNUM}"
    PARTNUM=$((PARTNUM+1))
fi

if [ "$SYSTEM_REQ" -eq 1 ]; then
    mkfs_safe mkfs.ext4 -F -L "SYSTEM" "${TARGET}${PARTNUM}"
    PARTNUM=$((PARTNUM+1))
fi

if [ "$IMAGES_REQ" -eq 1 ]; then
    mkfs_safe mkfs.ext4 -F -L "IMAGES" "${TARGET}${PARTNUM}"
fi

# ------------------------------------------------------------
#  EXTRACT TARBALLS
# ------------------------------------------------------------
PARTNUM=1

BOOT_TARBALL="boot.tar.gz"
if [ -n "$MODEL" ]; then
    BOOT_TARBALL="boot${MODEL}.tar.gz"
fi

if [ "$BOOT_REQ" -eq 1 ]; then
    echo "Extracting $BOOT_TARBALL..."
    mkdir -p /mnt/realboot
    mount "${TARGET}${PARTNUM}" /mnt/realboot
    tar -xzf "$BOOT_TARBALL" -C /mnt/realboot
    umount /mnt/realboot
    PARTNUM=$((PARTNUM+1))
fi

if [ "$SYSTEM_REQ" -eq 1 ]; then
    echo "Extracting system.tar.gz..."
    mkdir -p /mnt/system
    mount "${TARGET}${PARTNUM}" /mnt/system
    tar -xzf system.tar.gz -C /mnt/system
    umount /mnt/system
    PARTNUM=$((PARTNUM+1))
fi

echo "Done."
