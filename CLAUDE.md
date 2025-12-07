# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**dx** is a containerized multi-language development environment based on Debian Bookworm. It provides an interactive shell with pre-installed programming languages, tools, and utilities, designed to be used by developers and AI agents alike. The project supports Docker, Apple's `container` command, and systemd-nspawn.

## Core Architecture

### User Configuration
The container runs as the non-root user `dx` with the following properties:
- **Default UID/GID**: 1000/1000 (when built without `--current-user`)
- **With `--current-user`**: Uses your host user's UID/GID for seamless file permissions
- **Sudo access**: The `dx` user has passwordless sudo for system operations
- **Home directory**: `/home/dx` (all tools installed here)

Build arguments:
- `USER_UID` - User ID for the dx user (default: 1000)
- `USER_GID` - Group ID for the dx user (default: 1000)

The `--current-user` flag automatically passes your current UID/GID to ensure mounted files maintain proper ownership and permissions.

### Container Runtime Detection
The `dx` script automatically detects and uses one of three container runtimes with the following priority:
1. **systemd-nspawn** (if available and template exists at `/var/lib/machines/dx-template`)
2. **Apple's container command** (macOS)
3. **Docker**

This tri-runtime support is handled throughout:
- `dx` (main wrapper script) - detects runtime and executes containers
- `build.sh` - builds Docker/Container images
- `build-nspawn.sh` - builds systemd-nspawn template as btrfs subvolume

### Container Naming
Containers are automatically named based on the current working directory and version control branch (dx:59-78):
- Format: `dx-<project>-<branch>`
- Project name extracted from current directory basename
- Branch detected from jj (preferred) or git
- Names sanitized to contain only alphanumeric, underscore, period, and hyphen characters
- Example: `dx-myapp-feature-auth` for project "myapp" on branch "feature-auth"

### File Mounting Strategy
The project handles file mounting differently based on the container runtime:

**Docker**: Supports direct file mounts
- Individual files (`.gitconfig`, `.claude.json`, `/etc/localtime`) mounted directly
- Works with `-v` flag for files

**Apple Container**: Does not support file mounts
- Uses `~/.dx` staging directory to copy files into container
- Files are copied at container startup via inline shell script
- Directory mounts still work normally

**systemd-nspawn**: Supports bind mounts for files and directories
- Uses `--bind` and `--bind-ro` flags for mounts
- Runs in ephemeral mode (`--ephemeral`) using btrfs snapshots
- All container changes are discarded on exit
- Template stored at `/var/lib/machines/dx-template`

This workaround is implemented in `dx:76-116` with the `startup_script` variable containing commands executed at container start (for Apple Container).

### Persistent Storage
Always mounted from host:
- Current directory → `/workspace` (working directory)
- `~/.claude` → `/home/dx/.claude` (read-write, auto-created)
- `~/.ssh` → `/home/dx/.ssh` (read-only)
- `~/.config` → `/home/dx/.config` (read-only)
- `~/.cache` → `/home/dx/.cache` (read-write, if exists)

Environment variables passed through:
- `TZ` - timezone (or auto-detected from `/etc/localtime`)
- `ANTHROPIC_API_KEY` - for Claude Code authentication

### Resource Allocation
The container runs with default resource limits (Docker/Container only):
- **CPUs**: 4 cores
- **Memory**: 4GB

These are set in `dx:76-83` with runtime-specific flags:
- Docker: `--cpus=4 --memory=4g`
- Apple Container: `--cpus=4 --memory=4G`
- systemd-nspawn: No resource limits by default (uses host cgroups)

### Network Restrictions (systemd-nspawn only)
The `--restrict-network` flag enables network whitelisting, blocking all outbound connections except to known package registries and essential services.

**Whitelisted destinations:**
- DNS servers (1.1.1.1, 8.8.8.8)
- npm registry (registry.npmjs.org, registry.yarnpkg.com)
- Rust/Cargo (crates.io, static.crates.io, index.crates.io)
- Python/PyPI (pypi.org, files.pythonhosted.org)
- Go modules (proxy.golang.org, sum.golang.org)
- GitHub (github.com, api.github.com, raw.githubusercontent.com, etc.)
- Debian/Ubuntu apt repositories

**Implementation:** Uses iptables OUTPUT chain rules inside the container. Domains are resolved to IPs at container startup. Blocked connections are logged with prefix `DX-BLOCKED:` and rejected.

## Development Commands

### Building the Container (Docker/Apple Container)
```bash
# Build with local tag only (creates user 'dx' with UID=1000, GID=1000)
./build.sh

# Build with current user's UID/GID (recommended for local development)
./build.sh --current-user

# Build and tag for GitHub Container Registry
./build.sh your-github-username

# Build with specific version
./build.sh your-github-username v1.0.0

# Build with current user and GitHub tags
./build.sh --current-user your-github-username v1.0.0
```

**Note**: The `--current-user` flag builds the image with your current user's UID and GID, which ensures proper file permissions when mounting local directories. This is especially important for avoiding permission issues with mounted files like `.gitconfig`, `.ssh`, `.claude`, etc.

### Building the systemd-nspawn Template
```bash
# Build template (requires root)
sudo ./build-nspawn.sh

# Build with current user's UID/GID
sudo ./build-nspawn.sh --current-user

# Force rebuild (delete existing template first)
sudo ./build-nspawn.sh --rebuild
```

**Requirements for systemd-nspawn**:
- Must be run as root (uses debootstrap, btrfs subvolumes)
- Required packages: `debootstrap`, `systemd-container`, `btrfs-progs`

**Btrfs filesystem handling**:
- If `/var/lib/machines` is already on btrfs, it will be used directly
- If not, the script automatically creates a 20GB btrfs loopback volume at `/var/lib/dx-machines.img`
- The loopback volume is mounted at `/var/lib/machines` and an fstab entry is added for persistence

The template is created as a btrfs subvolume at `/var/lib/machines/dx-template`. When running, systemd-nspawn creates ephemeral snapshots of this template, so all changes inside the container are discarded on exit.

### Running the Environment
```bash
# Interactive shell
./dx

# Execute single command
./dx <command>

# Execute compound commands (quote them)
./dx "npm install && npm test"

# Run with verbose output (shows runtime, mounts, environment)
./dx -v
./dx --verbose

# Run with network restrictions (systemd-nspawn only)
# Only allows connections to package registries and GitHub
./dx --restrict-network

# Run command with network restrictions
./dx --restrict-network "npm install"

# Combine flags
./dx -v --restrict-network "npm install"
```

### Publishing to GHCR
```bash
# Login
echo $GITHUB_TOKEN | docker login ghcr.io -u username --password-stdin

# Build with tags
./build.sh username v1.0.0

# Push
docker push ghcr.io/username/dx:v1.0.0
docker push ghcr.io/username/dx:latest
```

## Installed Tools and Languages

### Languages
- **Node.js 20** (pnpm, bun, TypeScript, ts-node)
- **Go 1.22**
- **Rust** (stable, with rustfmt and clippy)
- **Python 3** (with uv package manager and ruff linter)

### Rust-based CLI Tools (installed via cargo)
- `bat` - syntax-highlighted cat
- `fd` - find alternative
- `ripgrep` (rg) - grep alternative
- `eza` - ls alternative
- `zoxide` - smart cd
- `delta` - git diff pager
- `starship` - shell prompt
- `jj` - Jujutsu version control

### Other Tools
- `fzf` - fuzzy finder
- `jq`, `yq` - JSON/YAML processors
- `fx` - JSON viewer (npm package)
- `xh` - HTTP client
- `gh` - GitHub CLI
- `chezmoi` - dotfile manager
- `tmux` - terminal multiplexer
- `neovim` - text editor
- `claude` - Claude Code CLI (@anthropic-ai/claude-code)

### Shell Configuration
- **zsh** with oh-my-zsh
- **Starship** prompt
- Aliases: `ls`→`eza`, `cat`→`bat`, `find`→`fd`, `grep`→`rg`
- Editor: `nvim`

## Architecture Patterns

### Runtime Abstraction
Functions follow this pattern for cross-runtime compatibility:
1. `detect_runtime()` - returns "nspawn", "container", or "docker"
2. Runtime-specific logic branches on the result
3. `generate_container_name()` - shared naming logic for all runtimes
4. Separate run functions: `run_nspawn()` for systemd-nspawn, `run_container()` for Docker/Apple

### Container Options Pattern (dx:69-145)
Common options array built dynamically based on:
- Runtime capabilities (file mounts vs directory staging)
- Host file/directory existence checks
- Environment variable presence

### Timezone Handling
Three-tier strategy:
1. If `TZ` env var set → use it
2. Else if `/etc/localtime` exists → mount/copy it
3. Else → use container default

## Version Control

This project uses **Jujutsu (jj)** as the version control system. The `.jj` directory structure indicates this is a jj repository. When working with version control:
- Use `jj` commands instead of `git` (though git may also be available in the container)
- Repository is located at `.jj/repo`
- Working copy tracking at `.jj/working_copy`

## Modifying the Project

### Adding New Tools
Add installation steps to `Dockerfile`:
- System packages: Add to `apt-get install` sections
- Rust tools: Add to `cargo install` line (Dockerfile:63)
- npm tools: Add `npm install -g` commands
- Go tools: Use `go install` commands
- Python tools: Use `uv tool install` commands

### Adding Shell Configuration
Append to `~/.zshrc` in Dockerfile (Dockerfile:133-140):
```dockerfile
RUN echo 'your command here' >> ~/.zshrc
```

### Modifying Mount Behavior
Edit the appropriate function in `dx`:
- `run_container()` for Docker/Apple Container: Add to `common_opts` array
- `run_nspawn()` for systemd-nspawn: Add to `nspawn_opts` array using `--bind` or `--bind-ro`
- Add runtime-specific sections for mounts that only work on certain runtimes
