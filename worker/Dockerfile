FROM ubuntu:24.04

ARG OPENCODE_VERSION=latest
ARG GH_VERSION=latest

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    bash \
    ca-certificates \
    nodejs \
    npm \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# OpenCode CLI
RUN curl -fsSL https://opencode.ai/install | bash \
    && ln -s /root/.opencode/bin/opencode /usr/local/bin/opencode

# Pre-install the openai-compatible AI SDK provider so opencode doesn't
# need to download it at runtime. Must be in the opencode config dir.
RUN mkdir -p /root/.config/opencode \
    && cd /root/.config/opencode \
    && npm init -y \
    && npm install @ai-sdk/openai-compatible

# Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Worker scripts
COPY worker/entrypoint.sh   /usr/local/bin/entrypoint
COPY worker/init-auth.sh    /usr/local/bin/init-auth
RUN chmod +x /usr/local/bin/entrypoint /usr/local/bin/init-auth

# init-auth configures git credentials from GH_TOKEN at container startup,
# then hands off to entrypoint. Auth is the container's responsibility;
# the entrypoint assumes git is already configured.
ENTRYPOINT ["/usr/local/bin/init-auth"]
