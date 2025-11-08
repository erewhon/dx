FROM debian:bookworm-slim

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH=/root/.cargo/bin:/usr/local/go/bin:/root/.local/bin:$PATH

# Install base dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg \
    lsb-release \
    pkg-config \
    software-properties-common \
    unzip \
    wget \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Install NodeJS (using NodeSource)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g pnpm typescript ts-node \
    && rm -rf /var/lib/apt/lists/*

# Install Golang
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then GO_ARCH="amd64"; \
    elif [ "$ARCH" = "arm64" ]; then GO_ARCH="arm64"; \
    else GO_ARCH="amd64"; fi && \
    wget -q https://go.dev/dl/go1.22.0.linux-${GO_ARCH}.tar.gz && \
    tar -C /usr/local -xzf go1.22.0.linux-${GO_ARCH}.tar.gz && \
    rm go1.22.0.linux-${GO_ARCH}.tar.gz

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . $HOME/.cargo/env && \
    rustup component add rustfmt clippy

# Install Python and uv
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/* && \
    curl -LsSf https://astral.sh/uv/install.sh | sh

# Install ruff
RUN /root/.cargo/bin/uv tool install ruff

# Install Rust-based tools (via cargo)
RUN . $HOME/.cargo/env && \
    cargo install bat bat-extras fd-find ripgrep eza zoxide

# Install fzf
RUN git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && \
    ~/.fzf/install --all

# Install jq, yq, and other tools
RUN apt-get update && apt-get install -y \
    jq \
    tmux \
    neovim \
    && rm -rf /var/lib/apt/lists/*

# Install yq (Go version)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then YQ_ARCH="amd64"; \
    elif [ "$ARCH" = "arm64" ]; then YQ_ARCH="arm64"; \
    else YQ_ARCH="amd64"; fi && \
    wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${YQ_ARCH} -O /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

# Install xh (httpie replacement)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then XH_ARCH="x86_64"; \
    elif [ "$ARCH" = "arm64" ]; then XH_ARCH="aarch64"; \
    else XH_ARCH="x86_64"; fi && \
    XH_VERSION=$(curl -s https://api.github.com/repos/ducaale/xh/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/') && \
    wget -q https://github.com/ducaale/xh/releases/download/v${XH_VERSION}/xh-v${XH_VERSION}-${XH_ARCH}-unknown-linux-musl.tar.gz && \
    tar -xzf xh-v${XH_VERSION}-${XH_ARCH}-unknown-linux-musl.tar.gz && \
    mv xh-v${XH_VERSION}-${XH_ARCH}-unknown-linux-musl/xh /usr/local/bin/ && \
    rm -rf xh-v${XH_VERSION}-${XH_ARCH}-unknown-linux-musl* && \
    chmod +x /usr/local/bin/xh

# Install fx (JSON viewer)
RUN npm install -g fx

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Install Jujutsu (jj)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then JJ_ARCH="x86_64"; \
    elif [ "$ARCH" = "arm64" ]; then JJ_ARCH="aarch64"; \
    else JJ_ARCH="x86_64"; fi && \
    JJ_VERSION=$(curl -s https://api.github.com/repos/martinvonz/jj/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/') && \
    wget -q https://github.com/martinvonz/jj/releases/download/v${JJ_VERSION}/jj-v${JJ_VERSION}-${JJ_ARCH}-unknown-linux-musl.tar.gz && \
    tar -xzf jj-v${JJ_VERSION}-${JJ_ARCH}-unknown-linux-musl.tar.gz && \
    mv jj /usr/local/bin/ && \
    rm jj-v${JJ_VERSION}-${JJ_ARCH}-unknown-linux-musl.tar.gz && \
    chmod +x /usr/local/bin/jj

# Install chezmoi
RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin

# Configure zsh as default shell
RUN chsh -s $(which zsh)

# Install oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Configure zsh with useful plugins and settings
RUN echo 'eval "$(zoxide init zsh)"' >> ~/.zshrc && \
    echo 'source ~/.fzf.zsh' >> ~/.zshrc && \
    echo 'alias ls="eza"' >> ~/.zshrc && \
    echo 'alias cat="bat"' >> ~/.zshrc && \
    echo 'alias find="fd"' >> ~/.zshrc && \
    echo 'alias grep="rg"' >> ~/.zshrc && \
    echo 'export EDITOR=nvim' >> ~/.zshrc

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/zsh"]
