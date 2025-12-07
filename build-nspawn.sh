#!/bin/bash

# build-nspawn.sh - Build the dx developer environment as a systemd-nspawn template
# Creates a Debian Bookworm-based btrfs subvolume with all dx tools
#
# Usage:
#   sudo ./build-nspawn.sh                     # Build template
#   sudo ./build-nspawn.sh --current-user      # Build with current user's UID/GID
#   sudo ./build-nspawn.sh --rebuild           # Force rebuild (delete existing)
#
# Requirements:
#   - Must be run as root (uses debootstrap, btrfs)
#   - Packages: debootstrap, systemd-container, btrfs-progs
#
# If /var/lib/machines is not on btrfs, the script will automatically create
# a btrfs loopback volume at /var/lib/dx-machines.img and mount it.

set -e

TEMPLATE_NAME="dx-template"
MACHINES_DIR="/var/lib/machines"
BTRFS_IMAGE="/var/lib/dx-machines.img"
BTRFS_IMAGE_SIZE="20G"
TEMPLATE_PATH="${MACHINES_DIR}/${TEMPLATE_NAME}"
DX_USER="dx"
USER_UID=1000
USER_GID=1000
REBUILD=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --current-user)
            # Get the invoking user's UID/GID (not root)
            if [ -n "$SUDO_UID" ]; then
                USER_UID=$SUDO_UID
                USER_GID=$SUDO_GID
            fi
            shift
            ;;
        --rebuild)
            REBUILD=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: sudo $0 [--current-user] [--rebuild]"
            exit 1
            ;;
    esac
done

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "error: this script must be run as root (use sudo)" >&2
    exit 1
fi

# Check for required commands
for cmd in debootstrap btrfs systemd-nspawn fallocate mkfs.btrfs; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "error: '$cmd' command not found" >&2
        echo "Install required packages: apt install debootstrap systemd-container btrfs-progs" >&2
        exit 1
    fi
done

# Check if /var/lib/machines is on btrfs, create loopback if not
ensure_btrfs_machines() {
    # Check if already mounted as btrfs
    if btrfs filesystem show "$MACHINES_DIR" &>/dev/null; then
        echo "Using existing btrfs filesystem at $MACHINES_DIR"
        return 0
    fi

    # Check if our loopback image exists and is mounted
    if [ -f "$BTRFS_IMAGE" ]; then
        if mountpoint -q "$MACHINES_DIR"; then
            echo "Loopback image already mounted at $MACHINES_DIR"
            return 0
        fi
        echo "Mounting existing btrfs loopback image..."
        mount -o loop "$BTRFS_IMAGE" "$MACHINES_DIR"
        return 0
    fi

    echo ""
    echo "=========================================="
    echo "Creating btrfs loopback volume"
    echo "=========================================="
    echo ""
    echo "$MACHINES_DIR is not on a btrfs filesystem."
    echo "Creating a ${BTRFS_IMAGE_SIZE} btrfs loopback volume at $BTRFS_IMAGE"
    echo ""

    # Ensure machines directory exists
    mkdir -p "$MACHINES_DIR"

    # Create the image file
    echo "Allocating ${BTRFS_IMAGE_SIZE} image file..."
    fallocate -l "$BTRFS_IMAGE_SIZE" "$BTRFS_IMAGE"

    # Format as btrfs
    echo "Formatting as btrfs..."
    mkfs.btrfs --csum=crc32c "$BTRFS_IMAGE"

    # Mount the loopback volume
    echo "Mounting loopback volume..."
    mount -o loop "$BTRFS_IMAGE" "$MACHINES_DIR"

    # Add fstab entry for persistence across reboots
    if ! grep -q "$BTRFS_IMAGE" /etc/fstab; then
        echo "Adding fstab entry for automatic mounting..."
        echo "$BTRFS_IMAGE $MACHINES_DIR btrfs loop 0 0" >> /etc/fstab
        echo "Added to /etc/fstab: $BTRFS_IMAGE $MACHINES_DIR btrfs loop 0 0"
    fi

    echo "Btrfs loopback volume created and mounted successfully."
    echo ""
}

ensure_btrfs_machines

# Handle existing template
if [ -d "$TEMPLATE_PATH" ]; then
    if [ "$REBUILD" = true ]; then
        echo "Removing existing template..."
        btrfs subvolume delete "$TEMPLATE_PATH" 2>/dev/null || rm -rf "$TEMPLATE_PATH"
    else
        echo "Template already exists at $TEMPLATE_PATH"
        echo "Use --rebuild to force rebuild"
        exit 0
    fi
fi

echo "Building dx-template systemd-nspawn container..."
echo "  Template: $TEMPLATE_PATH"
echo "  User UID: $USER_UID"
echo "  User GID: $USER_GID"
echo ""

# Create btrfs subvolume
echo "Creating btrfs subvolume..."
btrfs subvolume create "$TEMPLATE_PATH"

# Bootstrap Debian Bookworm
echo "Bootstrapping Debian Bookworm..."
debootstrap --include=systemd,dbus,locales bookworm "$TEMPLATE_PATH" http://deb.debian.org/debian

# Set locale
echo "Configuring locale..."
echo "en_US.UTF-8 UTF-8" > "$TEMPLATE_PATH/etc/locale.gen"
systemd-nspawn -D "$TEMPLATE_PATH" locale-gen
echo "LANG=en_US.UTF-8" > "$TEMPLATE_PATH/etc/locale.conf"

# Ensure /root exists and create installation script there (more reliable than /tmp)
mkdir -p "$TEMPLATE_PATH/root"

# Create installation script to run inside the container
cat > "$TEMPLATE_PATH/root/install-dx.sh" << 'INSTALL_SCRIPT'
#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

USER_UID=$1
USER_GID=$2

echo "=== Installing base dependencies ==="
apt-get update
apt-get install -y \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg \
    lsb-release \
    pkg-config \
    procps \
    software-properties-common \
    sudo \
    unzip \
    wget \
    zsh \
    findutils \
    jq \
    tmux \
    neovim \
    python3 \
    python3-pip \
    python3-venv

echo "=== Creating dx user ==="
groupadd -g ${USER_GID} dx || true
useradd -u ${USER_UID} -g ${USER_GID} -m -s /bin/zsh dx || true
echo "dx ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to dx user for remaining installations
echo "=== Installing Node.js ==="
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
npm install -g pnpm typescript ts-node fx @anthropic-ai/claude-code

echo "=== Installing Bun ==="
sudo -u dx bash -c 'curl -fsSL https://bun.sh/install | bash'

echo "=== Installing Go ==="
ARCH=$(dpkg --print-architecture)
if [ "$ARCH" = "amd64" ]; then GO_ARCH="amd64";
elif [ "$ARCH" = "arm64" ]; then GO_ARCH="arm64";
else GO_ARCH="amd64"; fi
wget -q https://go.dev/dl/go1.22.0.linux-${GO_ARCH}.tar.gz
tar -C /usr/local -xzf go1.22.0.linux-${GO_ARCH}.tar.gz
rm go1.22.0.linux-${GO_ARCH}.tar.gz

echo "=== Installing Rust ==="
sudo -u dx bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && source $HOME/.cargo/env && rustup component add rustfmt clippy'

echo "=== Installing uv and ruff ==="
sudo -u dx bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh && $HOME/.local/bin/uv tool install ruff'

echo "=== Installing Rust CLI tools ==="
sudo -u dx bash -c 'source $HOME/.cargo/env && cargo install bat fd-find ripgrep eza zoxide git-delta starship'

echo "=== Installing fzf ==="
sudo -u dx bash -c 'git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --all'

echo "=== Installing yq ==="
ARCH=$(dpkg --print-architecture)
if [ "$ARCH" = "amd64" ]; then YQ_ARCH="amd64";
elif [ "$ARCH" = "arm64" ]; then YQ_ARCH="arm64";
else YQ_ARCH="amd64"; fi
wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${YQ_ARCH} -O /usr/local/bin/yq
chmod +x /usr/local/bin/yq

echo "=== Installing xh ==="
ARCH=$(dpkg --print-architecture)
if [ "$ARCH" = "amd64" ]; then XH_ARCH="x86_64";
elif [ "$ARCH" = "arm64" ]; then XH_ARCH="aarch64";
else XH_ARCH="x86_64"; fi
XH_VERSION=$(curl -s https://api.github.com/repos/ducaale/xh/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
wget -q https://github.com/ducaale/xh/releases/download/v${XH_VERSION}/xh-v${XH_VERSION}-${XH_ARCH}-unknown-linux-musl.tar.gz
tar -xzf xh-v${XH_VERSION}-${XH_ARCH}-unknown-linux-musl.tar.gz
mv xh-v${XH_VERSION}-${XH_ARCH}-unknown-linux-musl/xh /usr/local/bin/
rm -rf xh-v${XH_VERSION}-${XH_ARCH}-unknown-linux-musl*
chmod +x /usr/local/bin/xh

echo "=== Installing GitHub CLI ==="
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt-get update
apt-get install -y gh

echo "=== Installing Jujutsu (jj) ==="
sudo -u dx bash -c 'source $HOME/.cargo/env && cargo install --git https://github.com/martinvonz/jj.git --locked jj-cli'

echo "=== Installing chezmoi ==="
sudo -u dx bash -c 'sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin'

echo "=== Installing oh-my-zsh ==="
sudo -u dx bash -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'

echo "=== Configuring zsh ==="
sudo -u dx bash -c 'cat >> ~/.zshrc << "EOF"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$HOME/.cargo/bin:/usr/local/go/bin:$HOME/.local/bin:$PATH"
eval "$(zoxide init zsh)"
source ~/.fzf.zsh
eval "$(starship init zsh)"
alias ls="eza"
alias cat="bat"
alias grep="rg"
export EDITOR=nvim
# Source local environment overrides (set by dx wrapper)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
EOF'

echo "=== Creating workspace directory ==="
mkdir -p /workspace
chown dx:dx /workspace

echo "=== Cleanup ==="
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -f /root/install-dx.sh

echo "=== Installation complete ==="
INSTALL_SCRIPT

chmod +x "$TEMPLATE_PATH/root/install-dx.sh"

# Run the installation script inside the container
echo "Running installation inside container (this may take a while)..."
systemd-nspawn -D "$TEMPLATE_PATH" /root/install-dx.sh "$USER_UID" "$USER_GID"

# Mark the template as read-only (optional, helps prevent accidental modification)
# btrfs property set "$TEMPLATE_PATH" ro true

echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="
echo ""
echo "Template created at: $TEMPLATE_PATH"
if [ -f "$BTRFS_IMAGE" ]; then
    echo "Btrfs loopback: $BTRFS_IMAGE"
fi
echo ""
echo "You can now run the dx environment with:"
echo "  ./dx                  # Start interactive shell"
echo "  ./dx <command>        # Run command in container"
echo ""
echo "The container will run in ephemeral mode using btrfs snapshots."
echo "All changes are discarded when the container exits."
echo "Use bind mounts (configured in dx script) for persistent data."
if [ -f "$BTRFS_IMAGE" ]; then
    echo ""
    echo "Note: The btrfs loopback volume will be automatically mounted on boot"
    echo "via the fstab entry. To manually mount: mount -o loop $BTRFS_IMAGE $MACHINES_DIR"
fi
