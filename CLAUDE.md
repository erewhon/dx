# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**dx** is a containerized multi-language development environment based on Debian Bookworm. It provides an interactive shell with pre-installed programming languages, tools, and utilities, designed to be used by developers and AI agents alike. The project supports both Docker and Apple's `container` command.

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
The `dx` script automatically detects and uses either Docker or Apple's `container` command. This dual-runtime support is handled throughout:
- `dx` (main wrapper script) - detects runtime and executes containers
- `build.sh` - builds images with runtime detection
- Both scripts share the same `detect_runtime()` pattern

### File Mounting Strategy
The project handles file mounting differently based on the container runtime:

**Docker**: Supports direct file mounts
- Individual files (`.gitconfig`, `.claude.json`, `/etc/localtime`) mounted directly
- Works with `-v` flag for files

**Apple Container**: Does not support file mounts
- Uses `~/.dx` staging directory to copy files into container
- Files are copied at container startup via inline shell script
- Directory mounts still work normally

This workaround is implemented in `dx:76-116` with the `startup_script` variable containing commands executed at container start.

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

## Development Commands

### Building the Container
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

### Running the Environment
```bash
# Interactive shell
./dx

# Execute single command
./dx <command>

# Execute compound commands (quote them)
./dx "npm install && npm test"
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
1. `detect_runtime()` - returns "container" or "docker"
2. Runtime-specific logic branches on the result
3. Build commands use same flags for both runtimes

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
Edit the `run_container()` function in `dx`:
- Add to `common_opts` array for both runtimes
- Or add to runtime-specific sections for Docker-only/Container-only mounts
