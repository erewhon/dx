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

- **Node.js 20** with pnpm and TypeScript
- **Go 1.22**
- **Rust** (latest stable) with rustfmt and clippy
- **Python 3** with uv and ruff

### Tools

- **fzf** - Fuzzy finder
- **bat** / bat-extras - Better cat with syntax highlighting
- **chezmoi** - Dotfile manager
- **eza** - Modern ls replacement
- **fd** - Fast find alternative
- **fx** - JSON viewer and processor
- **jq** - JSON processor
- **xh** - HTTP client (httpie alternative)
- **gh** - GitHub CLI
- **jj** - Jujutsu version control
- **neovim** - Modern vim
- **ripgrep** - Fast grep alternative
- **tmux** - Terminal multiplexer
- **yq** - YAML processor
- **zoxide** - Smarter cd command

### Shell Configuration

- **zsh** with oh-my-zsh
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
./build.sh
```

## Requirements

Either:
- Docker Desktop
- Apple's `container` command (available on macOS)

The `dx` script will automatically detect which is available and use it.
