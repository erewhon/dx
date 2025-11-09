# dx

Developer shell. Can be used by Claude and other AI agents.

The shell has a variety of programming languages, tools, and common agents in a containerized environment.

## Quick Start

```bash
# Start interactive shell
./dx

# Run a command in the container
./dx python --version
./dx "npm install && npm test"
```

The `dx` script automatically detects and works with both Docker and Apple's `container` command.

## Files

- **Dockerfile** - Multi-language development environment based on Debian Bookworm
- **dx** - Shell script to run the container interactively or execute commands
- **build.sh** - Helper script to explicitly build the image
- **.dockerignore** - Optimizes Docker build context
- **LICENSE** - MIT License

## Contents

Base Docker image: Debian Bookworm

### Languages and Platforms

- **Node.js 20** with pnpm, bun, and TypeScript
- **Go 1.22**
- **Rust** (latest stable) with rustfmt and clippy
- **Python 3** with uv and ruff

### Tools

- **fzf** - Fuzzy finder
- **bat** / bat-extras - Better cat with syntax highlighting
- **chezmoi** - Dotfile manager
- **claude** - Claude Code AI coding assistant
- **delta** - Syntax-highlighting pager for git and diff output
- **eza** - Modern ls replacement
- **fd** - Fast find alternative
- **fx** - JSON viewer and processor
- **jq** - JSON processor
- **xh** - HTTP client (httpie alternative)
- **gh** - GitHub CLI
- **jj** - Jujutsu version control
- **neovim** - Modern vim
- **ripgrep** - Fast grep alternative
- **starship** - Fast, customizable shell prompt
- **tmux** - Terminal multiplexer
- **yq** - YAML processor
- **zoxide** - Smarter cd command
- **procps** - Process utilities (ps, top, vmstat, etc.)

### Shell Configuration

- **zsh** with oh-my-zsh
- **Starship** prompt for a beautiful, informative shell experience
- Convenient aliases configured:
  - `ls` → `eza`
  - `cat` → `bat`
  - `find` → `fd`
  - `grep` → `rg`
- Default editor set to `nvim`

## Usage

### Interactive Shell

```bash
./dx
```

Starts a zsh shell with your current directory mounted at `/workspace`.

**Automatic mounts from host:**
- `.gitconfig` - Read-only (if exists)
- `.ssh` - Read-only (if exists)
- `.config` - Read-only (if exists)
- `.claude` - Read-write for Claude Code settings (always created/mounted)
- `.claude.json` - Read-write (if exists)
- `.cache` - Read-write for caching (if exists)
- `/etc/localtime` - For timezone (auto-detected)

**Note for Apple's `container` users:** Since Apple's container doesn't support file mounts, the script automatically uses a `~/.dx` staging directory to copy files (`.gitconfig`, `.claude.json`, `/etc/localtime`) into the container at startup.

**Timezone:** The container automatically uses your system timezone. You can override this by setting the `TZ` environment variable:

```bash
TZ=America/New_York ./dx
```

**Claude Code Authentication:** If you have `ANTHROPIC_API_KEY` set in your environment, it will be automatically passed through to the container. Make sure to export it before running `./dx`:

```bash
export ANTHROPIC_API_KEY="your-api-key"
./dx
```

### Run Commands

```bash
./dx <command>
```

Execute any command in the container:

```bash
./dx go version
./dx python -m pytest
./dx "cargo build && cargo test"
./dx npm run dev
```

### Building the Image

The `dx` script automatically builds the image if it doesn't exist. To rebuild explicitly:

```bash
# Build with local tag only
./build.sh

# Build and tag for GitHub Container Registry
./build.sh your-github-username

# Build with specific version
./build.sh your-github-username v1.0.0
```

### Publishing to GitHub Container Registry

To share your customized image via GitHub Container Registry:

1. **Create a GitHub Personal Access Token** with `write:packages` scope
   - Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Generate new token with `write:packages` and `read:packages` permissions

2. **Login to GitHub Container Registry:**

   ```bash
   # For Docker
   echo $GITHUB_TOKEN | docker login ghcr.io -u your-username --password-stdin

   # For Apple container
   echo $GITHUB_TOKEN | container login ghcr.io -u your-username --password-stdin
   ```

3. **Build and tag the image:**

   ```bash
   ./build.sh your-username v1.0.0
   ```

4. **Push to registry:**

   ```bash
   # For Docker
   docker push ghcr.io/your-username/dx:v1.0.0
   docker push ghcr.io/your-username/dx:latest

   # For Apple container
   container push ghcr.io/your-username/dx:v1.0.0
   container push ghcr.io/your-username/dx:latest
   ```

5. **Pull and use from anywhere:**

   ```bash
   docker pull ghcr.io/your-username/dx:latest
   # or
   container pull ghcr.io/your-username/dx:latest
   ```

   Note: By default, packages are private. To make public, go to the package page on GitHub and change visibility settings.

## Requirements

Either:
- Docker Desktop
- Apple's `container` command (available on macOS)

The `dx` script will automatically detect which is available and use it.
