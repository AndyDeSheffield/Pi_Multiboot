#!/usr/bin/env bash

set -u

ROOT=""
NAME=""
MODEL=""
SIZE=""
EXPAND=0

ARCH=""
TARGET_DIR=""
IMG_PATH=""
DTB_PATH=""
KERNEL_PATH=""
LOOPDEV=""
BOOTPART_DIR="./bootpart"

usage() {
    cat <<EOF
Usage: $0 -r=<root_mount> -n=<name_of_image> -m=<pi_model> -s=<size> [-e] [-h]
  -r=<root_mount>    Root of mounted image disk (e.g. -r=/mnt/realimages)
  -n=<name>          Name of image (letters, numbers, '-', '_')
  -m=<pi_model>      Pi model (e.g. pi4, pi5)
  -s=<size>          Image size (e.g. 10G)
  -e                 Expand root filesystem (only if exactly 2 partitions exist)
  -h                 Show this help
  Note that the script needs to be run with sudo
EOF
}

# --- argument parsing ---
for arg in "$@"; do
    case "$arg" in
        -r=*) ROOT="${arg#*=}" ;;
        -n=*) NAME="${arg#*=}" ;;
        -m=*) MODEL="${arg#*=}" ;;
        -s=*) SIZE="${arg#*=}" ;;
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


if [[ -z "$ROOT" || -z "$NAME" || -z "$MODEL" || -z "$SIZE" ]]; then
    echo "Missing required arguments." >&2
    usage
    exit 1
fi

if [[ ! -d "$ROOT" ]]; then
    echo "Root mount does not exist or is not a directory: $ROOT" >&2
    exit 1
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
        sync
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

generate_grub_entry() {
    local name="$1"
    local model="$2"
    local target_dir="$3"
    local grub_base="./grub.base"

    # Replace underscores with spaces for the menu title
    local title="${name//_/ }"

    local grubfile="${target_dir}/Grub_${name}_${model}.cfg"

    echo "Generating GRUB entry: $grubfile"

    {
        echo "menuentry \"${title}\" {"
        echo "    set osname=\"${name}_${model}\""
        cat "$grub_base"

        # Add initrd lines only if initramfs files exist
        if compgen -G "${target_dir}/initramfs*" > /dev/null; then
            for f in "${target_dir}"/initramfs*; do
                base=$(basename "$f")
                echo "    initrd \${osdir}/${base}"
            done
        elif [[ -f "${target_dir}/initrd.img" ]]; then
            echo "    initrd \${osdir}/initrd.img"
        fi

        echo "}"
    } > "$grubfile"

    echo "GRUB entry written to: Grub_${name}_${model}.cfg"
}

# safety cleanup
trap '
cleanup_bootpart_mount
cleanup_bootpart_dir
[[ -n "${LOOPDEV:-}" ]] && losetup -d "$LOOPDEV" 2>/dev/null || true
' EXIT

# --- Step 1 ---
echo "Step 1: Creating target directory and blank image..."

mkdir -p "$TARGET_DIR"

if [[ -e "$IMG_PATH" ]]; then
    echo "Image file already exists: $IMG_PATH" >&2
    abort1
    exit 1
fi

truncate -s "$SIZE" "$IMG_PATH"

echo "Created image: $IMG_PATH (size $SIZE)"
prompt_step 1 abort1

# --- Step 2 ---
echo "Step 2: Loop-mounting image and running Raspberry Pi Imager..."

LOOPDEV=$(losetup --find --show "$IMG_PATH" 2>/dev/null || true)
[[ -z "$LOOPDEV" ]] && echo "Failed to create loop device." && abort2 && exit 1

echo "Loop device: $LOOPDEV"

if [[ ! -x "./$ARCH/Raspberry_Pi_Imager-$ARCH.AppImage" ]]; then
    echo "Imager not found: ./$ARCH/Raspberry_Pi_Imager-$ARCH.AppImage" >&2
    abort2
    exit 1
fi

echo "Launching Raspberry Pi Imager..."
"./$ARCH/Raspberry_Pi_Imager-$ARCH.AppImage" >/dev/null 2>&1

echo "Refreshing loop partitions..."
losetup -d "$LOOPDEV"
LOOPDEV=$(losetup --find --show --partscan "$IMG_PATH" 2>/dev/null || true)
[[ -z "$LOOPDEV" ]] && echo "Failed to reattach loop device." && abort2 && exit 1

echo "Reattached loop device: $LOOPDEV"
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

"./$ARCH/merge-dtb-$ARCH" -b "$BOOTPART_DIR" -o "$DTB_PATH" -m "$MODEL" -v 4

CONFIG_FILE="$BOOTPART_DIR/config.txt"
KERNEL_NAME=""

if [[ -f "$CONFIG_FILE" ]]; then
    KERNEL_LINE=$(grep -E '^kernel=' "$CONFIG_FILE" | tail -n 1 || true)
    [[ -n "$KERNEL_LINE" ]] && KERNEL_NAME="${KERNEL_LINE#kernel=}"
fi

if [[ -z "$KERNEL_NAME" ]]; then
    case "$MODEL" in
        pi4) KERNEL_NAME="kernel8.img" ;;
        pi5) KERNEL_NAME="kernel_2712.img" ;;
        *)   KERNEL_NAME="kernel8.img" ;;
    esac
    echo "Defaulting kernel to $KERNEL_NAME"
else
    echo "Kernel from config.txt: $KERNEL_NAME"
fi

KERNEL_SRC=$(find "$BOOTPART_DIR" -name "$KERNEL_NAME" -print -quit)
[[ -z "$KERNEL_SRC" ]] && echo "Kernel not found." && abort2 && exit 1

cp "$KERNEL_SRC" "$KERNEL_PATH"

# --- Step 3.6: Initramfs detection ---
echo "Step 3.6: Checking for initramfs..."

INITRAMFS_FILES=()

# auto_initramfs
if grep -q "^auto_initramfs=1" "$CONFIG_FILE" 2>/dev/null; then
    echo "auto_initramfs=1 detected."
    base="${KERNEL_NAME%.*}"
    initname="initramfs${base#kernel}"
    INITRAMFS_FILES+=("$initname")
fi

# explicit initramfs lines
while IFS= read -r line; do
    files_part=$(echo "$line" | awk '{print $2}')
    IFS=',' read -ra arr <<< "$files_part"
    for f in "${arr[@]}"; do INITRAMFS_FILES+=("$f"); done
done < <(grep -E "^initramfs " "$CONFIG_FILE" 2>/dev/null || true)

if [[ ${#INITRAMFS_FILES[@]} -eq 0 ]]; then
    echo "No initramfs detected."
else
    echo "Initramfs files: ${INITRAMFS_FILES[*]}"
    for f in "${INITRAMFS_FILES[@]}"; do
        SRC=$(find "$BOOTPART_DIR" -name "$f" -print -quit)
        if [[ -z "$SRC" ]]; then
            echo "Warning: initramfs '$f' not found."
        else
            echo "Copying initramfs '$f'..."
            cp "$SRC" "$TARGET_DIR/$f"
        fi
    done
fi

# --- Step 3.5: Optional expansion ---
echo "Step 3.7: Optional expansion..."

ROOTPART_DEV="${LOOPDEV}p2"
PART3_DEV="${LOOPDEV}p3"

if [[ $EXPAND -eq 0 ]]; then
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

# cleanup
cleanup_bootpart_mount
cleanup_bootpart_dir
losetup -d "$LOOPDEV" || true
LOOPDEV=""

generate_grub_entry "$NAME" "$MODEL" "$TARGET_DIR"

echo
echo "Image creation completed successfully."
echo "Directory: $TARGET_DIR"
echo " IMG      : $IMG_PATH"
echo " DTB      : $DTB_PATH"
echo " KERNEL   : $KERNEL_PATH"
echo " INITRAMFS: copied if present"
echo " GRUBENTRY: $GRUB_PATH"
