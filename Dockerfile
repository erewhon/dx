FROM debian:bookworm-slim

# Build arguments for user creation
ARG USER_UID=1000
ARG USER_GID=1000

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH=/home/dx/.bun/bin:/home/dx/.cargo/bin:/usr/local/go/bin:/home/dx/.local/bin:$PATH

# Install base dependencies
RUN apt-get update && apt-get install -y \
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
    && rm -rf /var/lib/apt/lists/*

# Create dx user with specified UID/GID
RUN groupadd -g ${USER_GID} dx && \
    useradd -u ${USER_UID} -g ${USER_GID} -m -s /bin/zsh dx && \
    echo "dx ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to dx user for installations
USER dx
WORKDIR /home/dx

# Install NodeJS (using NodeSource)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash - \
    && sudo apt-get install -y nodejs \
    && sudo npm install -g pnpm typescript ts-node \
    && sudo rm -rf /var/lib/apt/lists/*

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash && \
    echo 'export BUN_INSTALL="$HOME/.bun"' >> ~/.zshrc && \
    echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.zshrc

# Install Golang
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then GO_ARCH="amd64"; \
    elif [ "$ARCH" = "arm64" ]; then GO_ARCH="arm64"; \
    else GO_ARCH="amd64"; fi && \
    wget -q https://go.dev/dl/go1.22.0.linux-${GO_ARCH}.tar.gz && \
    sudo tar -C /usr/local -xzf go1.22.0.linux-${GO_ARCH}.tar.gz && \
    rm go1.22.0.linux-${GO_ARCH}.tar.gz

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . $HOME/.cargo/env && \
    rustup component add rustfmt clippy

# Install Python and uv
RUN sudo apt-get update && sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && sudo rm -rf /var/lib/apt/lists/* && \
    curl -LsSf https://astral.sh/uv/install.sh | sh

# Install ruff
RUN $HOME/.local/bin/uv tool install ruff

# Install Rust-based tools (via cargo)
RUN . $HOME/.cargo/env && \
    cargo install bat fd-find ripgrep eza zoxide git-delta starship

# Install bat-extras (bash scripts, not cargo)
#RUN mkdir -p /tmp/bat-extras && \
#    for i in 1 2 3; do \
#        git clone --depth 1 https://github.com/eth-p/bat-extras.git /tmp/bat-extras && break || sleep 5; \
#    done && \
#    cd /tmp/bat-extras && \
#    ./build.sh --install && \
#    cd && \
#    rm -rf /tmp/bat-extras

# Install fzf
RUN for i in 1 2 3; do \
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && break || sleep 5; \
    done && \
    ~/.fzf/install --all

# Install jq, yq, and other tools
RUN sudo apt-get update && sudo apt-get install -y \
    findutils \
    jq \
    tmux \
    neovim \
    && sudo rm -rf /var/lib/apt/lists/*

# Install yq (Go version)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then YQ_ARCH="amd64"; \
    elif [ "$ARCH" = "arm64" ]; then YQ_ARCH="arm64"; \
    else YQ_ARCH="amd64"; fi && \
    wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${YQ_ARCH} -O /tmp/yq && \
    sudo mv /tmp/yq /usr/local/bin/yq && \
    sudo chmod +x /usr/local/bin/yq

# Install xh (httpie replacement)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then XH_ARCH="x86_64"; \
    elif [ "$ARCH" = "arm64" ]; then XH_ARCH="aarch64"; \
    else XH_ARCH="x86_64"; fi && \
    XH_VERSION=$(curl -s https://api.github.com/repos/ducaale/xh/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/') && \
    wget -q https://github.com/ducaale/xh/releases/download/v${XH_VERSION}/xh-v${XH_VERSION}-${XH_ARCH}-unknown-linux-musl.tar.gz && \
    tar -xzf xh-v${XH_VERSION}-${XH_ARCH}-unknown-linux-musl.tar.gz && \
    sudo mv xh-v${XH_VERSION}-${XH_ARCH}-unknown-linux-musl/xh /usr/local/bin/ && \
    rm -rf xh-v${XH_VERSION}-${XH_ARCH}-unknown-linux-musl* && \
    sudo chmod +x /usr/local/bin/xh

# Install fx (JSON viewer)
RUN sudo npm install -g fx

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    sudo apt-get update && \
    sudo apt-get install -y gh && \
    sudo rm -rf /var/lib/apt/lists/*

# Install Jujutsu (jj) - using cargo for reliability
RUN . $HOME/.cargo/env && \
    cargo install --git https://github.com/martinvonz/jj.git --locked jj-cli

# Install chezmoi
RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin

# Install oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Configure zsh with useful plugins and settings
RUN echo 'eval "$(zoxide init zsh)"' >> ~/.zshrc && \
    echo 'source ~/.fzf.zsh' >> ~/.zshrc && \
    echo 'eval "$(starship init zsh)"' >> ~/.zshrc && \
    echo 'alias ls="eza"' >> ~/.zshrc && \
    echo 'alias cat="bat"' >> ~/.zshrc && \
    echo 'alias grep="rg"' >> ~/.zshrc && \
    echo 'export EDITOR=nvim' >> ~/.zshrc

# Install Claude Code
RUN sudo npm install -g @anthropic-ai/claude-code

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/zsh"]
