#!/bin/bash

# expand-loopback.sh - Expand the /var/lib/machines btrfs loopback filesystem
#
# Usage:
#   sudo ./expand-loopback.sh              # Add 10G (default)
#   sudo ./expand-loopback.sh 20G          # Add 20G
#   sudo ./expand-loopback.sh --set 50G    # Set total size to 50G
#
# Requirements:
#   - Must be run as root
#   - Existing loopback image at /var/lib/dx-machines.img

set -e

BTRFS_IMAGE="/var/lib/dx-machines.img"
MACHINES_DIR="/var/lib/machines"
DEFAULT_ADD_SIZE="10G"
MODE="add"  # "add" or "set"
SIZE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --set)
            MODE="set"
            shift
            if [[ $# -gt 0 ]]; then
                SIZE="$1"
                shift
            else
                echo "error: --set requires a size argument (e.g., --set 50G)" >&2
                exit 1
            fi
            ;;
        -h|--help)
            echo "Usage: sudo $0 [SIZE] [--set SIZE]"
            echo ""
            echo "Expand the btrfs loopback filesystem at $BTRFS_IMAGE"
            echo ""
            echo "Options:"
            echo "  SIZE        Amount to add (default: $DEFAULT_ADD_SIZE)"
            echo "              Examples: 5G, 10G, 20G"
            echo "  --set SIZE  Set the total size instead of adding"
            echo "              Examples: --set 50G, --set 100G"
            echo "  -h, --help  Show this help message"
            echo ""
            echo "Examples:"
            echo "  sudo $0           # Add 10G to current size"
            echo "  sudo $0 20G       # Add 20G to current size"
            echo "  sudo $0 --set 50G # Set total size to 50G"
            exit 0
            ;;
        *)
            if [[ -z "$SIZE" ]]; then
                SIZE="$1"
            else
                echo "error: unexpected argument: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# Default size if not specified
if [[ -z "$SIZE" ]]; then
    SIZE="$DEFAULT_ADD_SIZE"
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "error: this script must be run as root (use sudo)" >&2
    exit 1
fi

# Check for required commands
for cmd in btrfs losetup truncate; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "error: '$cmd' command not found" >&2
        exit 1
    fi
done

# Check if loopback image exists
if [ ! -f "$BTRFS_IMAGE" ]; then
    echo "error: loopback image not found at $BTRFS_IMAGE" >&2
    echo "The loopback filesystem has not been created yet." >&2
    echo "Run ./build-nspawn.sh first to create it." >&2
    exit 1
fi

# Parse size to bytes for comparison
parse_size_to_bytes() {
    local size="$1"
    local num="${size%[GgMmKkTt]*}"
    local unit="${size##*[0-9]}"

    case "${unit^^}" in
        G) echo $((num * 1024 * 1024 * 1024)) ;;
        M) echo $((num * 1024 * 1024)) ;;
        K) echo $((num * 1024)) ;;
        T) echo $((num * 1024 * 1024 * 1024 * 1024)) ;;
        *) echo "$num" ;;
    esac
}

# Get current size
CURRENT_SIZE=$(stat -c%s "$BTRFS_IMAGE")
CURRENT_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B "$CURRENT_SIZE")

echo "Loopback image: $BTRFS_IMAGE"
echo "Current size: $CURRENT_SIZE_HUMAN"
echo ""

# Calculate new size
if [[ "$MODE" == "set" ]]; then
    NEW_SIZE_BYTES=$(parse_size_to_bytes "$SIZE")
    if [[ $NEW_SIZE_BYTES -le $CURRENT_SIZE ]]; then
        echo "error: new size ($SIZE) must be larger than current size ($CURRENT_SIZE_HUMAN)" >&2
        echo "Shrinking btrfs filesystems is not supported." >&2
        exit 1
    fi
    NEW_SIZE="$SIZE"
    ADD_SIZE_BYTES=$((NEW_SIZE_BYTES - CURRENT_SIZE))
    ADD_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B "$ADD_SIZE_BYTES")
    echo "Setting total size to: $SIZE (adding $ADD_SIZE_HUMAN)"
else
    ADD_SIZE_BYTES=$(parse_size_to_bytes "$SIZE")
    NEW_SIZE_BYTES=$((CURRENT_SIZE + ADD_SIZE_BYTES))
    NEW_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B "$NEW_SIZE_BYTES")
    echo "Adding: $SIZE"
    echo "New total size: $NEW_SIZE_HUMAN"
fi

echo ""

# Check if filesystem is mounted
LOOP_DEVICE=""
if mountpoint -q "$MACHINES_DIR"; then
    # Find the loop device
    LOOP_DEVICE=$(losetup -j "$BTRFS_IMAGE" | cut -d: -f1)
    if [[ -z "$LOOP_DEVICE" ]]; then
        echo "error: $MACHINES_DIR is mounted but can't find loop device" >&2
        exit 1
    fi
    echo "Filesystem is mounted at $MACHINES_DIR (loop device: $LOOP_DEVICE)"
    MOUNTED=true
else
    echo "Filesystem is not currently mounted"
    MOUNTED=false
fi

echo ""
echo "Expanding loopback image..."

# Expand the image file
if [[ "$MODE" == "set" ]]; then
    truncate -s "$SIZE" "$BTRFS_IMAGE"
else
    # For adding, we use the current size plus the addition
    truncate -s "+$SIZE" "$BTRFS_IMAGE"
fi

echo "Image file expanded successfully."

# If mounted, we need to resize the loop device and filesystem
if [[ "$MOUNTED" == true ]]; then
    echo "Resizing loop device..."
    losetup -c "$LOOP_DEVICE"

    echo "Resizing btrfs filesystem..."
    btrfs filesystem resize max "$MACHINES_DIR"

    echo ""
    echo "Filesystem resized successfully."
else
    echo ""
    echo "The image file has been expanded."
    echo "The btrfs filesystem will be resized when next mounted."
    echo ""
    echo "To mount and resize now:"
    echo "  mount -o loop $BTRFS_IMAGE $MACHINES_DIR"
    echo "  btrfs filesystem resize max $MACHINES_DIR"
fi

echo ""

# Show new size
NEW_ACTUAL_SIZE=$(stat -c%s "$BTRFS_IMAGE")
NEW_ACTUAL_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B "$NEW_ACTUAL_SIZE")
echo "New image size: $NEW_ACTUAL_SIZE_HUMAN"

if [[ "$MOUNTED" == true ]]; then
    echo ""
    echo "Filesystem usage:"
    btrfs filesystem usage -h "$MACHINES_DIR" 2>/dev/null | head -10 || btrfs filesystem df "$MACHINES_DIR"
fi

echo ""
echo "Done!"
