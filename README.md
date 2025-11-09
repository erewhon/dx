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

Starts a zsh shell with your current directory mounted at `/workspace`. Your `.gitconfig` and `.ssh` directory are automatically mounted (read-only) if they exist.

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
