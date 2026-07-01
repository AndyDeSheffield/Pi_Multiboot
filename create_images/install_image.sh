#!/usr/bin/env bash

set -u

ROOT=""
NAME=""
MODEL=""
SIZE=""
EXPAND=0
CUSTOMISE=0
IMPORT_IMAGE=""

ARCH=""
TARGET_DIR=""
IMG_PATH=""
DTB_PATH=""
KERNEL_PATH=""
LOOPDEV=""
BOOTPART_DIR="./bootpart"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
Usage: $0 -r=<root_mount> -n=<name_of_image> -m=<pi_model>
          (-s=<size> | -i=<existing_image>) [-c] [-e] [-h]

  -r=<root_mount>    Root of mounted image disk
  -n=<name>          Name of image
  -m=<pi_model>      Pi model (pi3b, pi3b+, pi4, pi5)
  -s=<size>          Create blank image of this size
  -i=<image>         Import an existing image file
  -c                 Apply custom files
  -e                 Expand root filesystem
  -h                 Show this help

When -i is specified:
  * the image is copied into the target directory
  * Raspberry Pi Imager is not run
  * filesystem expansion (-e) is ignored
EOF
}

# --- argument parsing ---
for arg in "$@"; do
    case "$arg" in
        -r=*) ROOT="${arg#*=}" ;;
        -n=*) NAME="${arg#*=}" ;;
        -m=*) MODEL="${arg#*=}" ;;
        -s=*) SIZE="${arg#*=}" ;;
        -i=*) IMPORT_IMAGE="${arg#*=}" ;;
        -c)   CUSTOMISE=1 ;;
        -e)   EXPAND=1 ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            usage
            exit 1
            ;;
    esac
done

# --- privilege check ---
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    echo "Try: sudo $0 $*"
    exit 1
fi

if [[ -z "$ROOT" || -z "$NAME" || -z "$MODEL" ]]; then
    echo "Missing required arguments." >&2
    usage
    exit 1
fi

if [[ -z "$SIZE" && -z "$IMPORT_IMAGE" ]]; then
    echo "Either -s or -i must be specified." >&2
    exit 1
fi

if [[ -n "$SIZE" && -n "$IMPORT_IMAGE" ]]; then
    echo "Specify either -s or -i, not both." >&2
    exit 1
fi

if [[ ! -d "$ROOT" ]]; then
    echo "Root mount does not exist or is not a directory: $ROOT" >&2
    exit 1
fi
if [[ -n "$IMPORT_IMAGE" ]]; then
    echo
    echo "NOTE:"
    echo "  Existing image import selected."
    echo "  Raspberry Pi Imager will not be run."
    echo "  Filesystem expansion (-e) is disabled."
    echo
fi
# --- arch detection ---
case "$(uname -m)" in
    x86_64) ARCH="x64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

TARGET_DIR="${ROOT}/${NAME}_${MODEL}"
IMG_PATH="${TARGET_DIR}/${NAME}_${MODEL}.img"
DTB_PATH="${TARGET_DIR}/${NAME}_${MODEL}.dtb"
KERNEL_PATH="${TARGET_DIR}/${NAME}_${MODEL}.kernel"
GRUB_PATH="${TARGET_DIR}/Grub_${NAME}_${MODEL}.cfg"

# --- helpers ---

cleanup_bootpart_mount() {
    if [[ -d "$BOOTPART_DIR" ]] && mountpoint -q "$BOOTPART_DIR" 2>/dev/null; then
        echo "[cleanup] Forcing release of $BOOTPART_DIR..."
        fuser -km "$BOOTPART_DIR" 2>/dev/null || true
        sleep 0.2
        umount "$BOOTPART_DIR" || true
    fi
}

cleanup_bootpart_dir() {
    [[ -d "$BOOTPART_DIR" ]] && rmdir "$BOOTPART_DIR" 2>/dev/null || true
}

abort1() {
    echo "[abort1] Removing image and directory..."
    rm -rf "$TARGET_DIR"
}

abort2() {
    echo "[abort2] Cleaning up loop device and image..."
    cleanup_bootpart_mount
    cleanup_bootpart_dir
    [[ -n "${LOOPDEV:-}" ]] && losetup -d "$LOOPDEV" 2>/dev/null || true
    abort1
}

prompt_step() {
    local step="$1"
    local abort_fn="$2"
    echo
    read -r -p "Step ${step} completed. Continue (c) or Abort (a)? [c/a]: " ans
    case "$ans" in
        a|A) echo "Aborting at step ${step}..."; $abort_fn; exit 1 ;;
        c|C|"") echo "Continuing..." ;;
        *) echo "Invalid choice, assuming abort."; $abort_fn; exit 1 ;;
    esac
}

handle_uefi_fixes() {
    echo "Handling uefi fixes. Installing cpufix.dtbo, dmafix.dtbo and uefi_fixes.txt"
    OVERLAYS_DIR=$(find "$BOOTPART_DIR" -type d -name "overlays" | head -1)

    if [ ! -f "$OVERLAYS_DIR/cpufix.dtbo" ]; then
        cp "$SCRIPT_DIR/cpufix.dtbo" "$OVERLAYS_DIR/cpufix.dtbo"
    fi

    if dtc -I dtb -O dts "$OVERLAYS_DIR"/../bcm2711-rpi-4-b.dtb 2>/dev/null | grep -q "emmc2-bus@"; then
        echo "Ubuntu-style DTB detected - installing dmafix-ubuntu.dtbo as dmafix.dtbo"
        cp "$SCRIPT_DIR/dmafix-ubuntu.dtbo" "$OVERLAYS_DIR/dmafix.dtbo"
    else
        if [ ! -f "$OVERLAYS_DIR/dmafix.dtbo" ]; then
            cp "$SCRIPT_DIR/dmafix.dtbo" "$OVERLAYS_DIR/dmafix.dtbo"
        fi
    fi

    UEFI_EXTRAS="$BOOTPART_DIR/uefi_fixes.txt"
    cp "$SCRIPT_DIR/uefi_fixes.txt" "$UEFI_EXTRAS"
}

generate_grub_entry() {
    local name="$1"
    local model="$2"
    local target_dir="$3"
    local grub_base="./grub.base"

    local title="${name//_/ }"
    local grubfile="${target_dir}/${name}_${model}_grub.cfg"

    echo "Generating GRUB entry: $grubfile"

    {
        echo "menuentry \"${title}\" {"
        echo "    set osname=\"${name}_${model}\""
        cat "$SCRIPT_DIR/$grub_base"

        if compgen -G "${target_dir}/*.initrd" > /dev/null; then
            for f in "${target_dir}"/*.initrd; do
                base=$(basename "$f")
                echo "    initrd \${osdir}/${base}"
            done
        fi

        echo "}"
    } > "$grubfile"

    echo "GRUB entry written to: Grub_${name}_${model}.cfg"
}

trap '
cleanup_bootpart_mount
cleanup_bootpart_dir
[[ -n "${LOOPDEV:-}" ]] && losetup -d "$LOOPDEV" 2>/dev/null || true
' EXIT

# --- Step 1 ---
echo "Step 1: Preparing image..."

mkdir -p "$TARGET_DIR"

if [[ -e "$IMG_PATH" ]]; then
    echo "Image file already exists: $IMG_PATH" >&2
    abort1
    exit 1
fi

if [[ -n "$IMPORT_IMAGE" ]]; then

    echo "Copying existing image $IMPORT_IMAGE to $IMG_PATH ... "

    if [[ ! -f "$IMPORT_IMAGE" ]]; then
        echo "Source image not found: $IMPORT_IMAGE" >&2
        abort1
        exit 1
    fi
	if ! rsync -ah --info=progress2 \
			"$IMPORT_IMAGE" \
			"$IMG_PATH"; then
		echo "Failed to copy image." >&2
		abort1
		exit 1
	fi
    echo "Copied:"
    echo "  $IMPORT_IMAGE"
    echo "to"
    echo "  $IMG_PATH"

else

    echo "Creating blank image..."
    truncate -s "$SIZE" "$IMG_PATH"
    echo "Created image: $IMG_PATH (size $SIZE)"

fi

prompt_step 1 abort1

# --- Step 2 ---
echo "Step 2: Preparing loop device..."

if [[ -n "$IMPORT_IMAGE" ]]; then

    echo "Using imported image."

    LOOPDEV=$(losetup --find --show --partscan "$IMG_PATH" 2>/dev/null || true)

    [[ -z "$LOOPDEV" ]] && {
        echo "Failed to attach loop device."
        abort2
        exit 1
    }

else

    echo "Loop-mounting image and running Raspberry Pi Imager..."

    LOOPDEV=$(losetup --find --show "$IMG_PATH" 2>/dev/null || true)

    [[ -z "$LOOPDEV" ]] && {
        echo "Failed to create loop device."
        abort2
        exit 1
    }

    echo "Loop device: $LOOPDEV"

    if [[ ! -x "./$ARCH/Raspberry_Pi_Imager-$ARCH.AppImage" ]]; then
        echo "Imager not found: ./$ARCH/Raspberry_Pi_Imager-$ARCH.AppImage" >&2
        abort2
        exit 1
    fi

    echo "Launching Raspberry Pi Imager..."
    "./$ARCH/Raspberry_Pi_Imager-$ARCH.AppImage" >/dev/null 2>&1
    sync
    echo "Refreshing loop partitions..."
    losetup -d "$LOOPDEV"

    LOOPDEV=$(losetup --find --show --partscan "$IMG_PATH" 2>/dev/null || true)

    [[ -z "$LOOPDEV" ]] && {
        echo "Failed to reattach loop device."
        abort2
        exit 1
    }
fi

echo "Attached loop device: $LOOPDEV"
prompt_step 2 abort2

# --- Step 3 ---
echo "Step 3: Extracting DTB and kernel..."

mkdir -p "$BOOTPART_DIR"

BOOTPART_DEV="${LOOPDEV}p1"
[[ ! -b "$BOOTPART_DEV" ]] && echo "Boot partition not found." && abort2 && exit 1

mount "$BOOTPART_DEV" "$BOOTPART_DIR"

if [[ ! -x "./$ARCH/merge-dtb-$ARCH" ]]; then
    echo "merge-dtb tool not found." >&2
    abort2
    exit 1
fi

handle_uefi_fixes

"./$ARCH/merge-dtb-$ARCH" \
    -b "$BOOTPART_DIR" \
    -o "$DTB_PATH" \
    -m "$MODEL" \
    -x -v3

# --- Step 4 ---
echo "Step 4: Optional expansion..."

ROOTPART_DEV="${LOOPDEV}p2"
PART3_DEV="${LOOPDEV}p3"

if [[ -n "$IMPORT_IMAGE" ]]; then
    echo "Imported image specified. Expansion disabled."
elif [[ $EXPAND -eq 0 ]]; then
    echo "Expansion disabled."
elif [[ -b "$PART3_DEV" ]]; then
    echo "Partition 3 exists. Not expanding."
elif [[ ! -b "$ROOTPART_DEV" ]]; then
    echo "Root partition missing. Skipping."
else
    echo "Expanding root filesystem..."

    parted -s "$LOOPDEV" print
    parted -s "$LOOPDEV" resizepart 2 100%
    e2fsck -f "$ROOTPART_DEV"
    resize2fs "$ROOTPART_DEV"

    echo "Expansion complete."
fi

cleanup_bootpart_mount
cleanup_bootpart_dir
losetup -d "$LOOPDEV" || true
LOOPDEV=""

# --- Step 5 ---
echo "Step 5: Optional customisation..."

generate_grub_entry "$NAME" "$MODEL" "$TARGET_DIR"

if [[ $CUSTOMISE -eq 1 ]]; then
    echo "Running customisation (may overwrite generated grub entry)..."
    python3 "$SCRIPT_DIR/deploy_custom_files.py" "$IMG_PATH"
fi

echo "Image creation completed successfully."
echo "Directory: $TARGET_DIR"
ls -l "$TARGET_DIR"