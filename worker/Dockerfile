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
RUN curl -fsSL https://opencode.ai/install | bash

# Worker scripts
COPY worker/entrypoint.sh /usr/local/bin/entrypoint
COPY worker/init-auth.sh  /usr/local/bin/init-auth
RUN chmod +x /usr/local/bin/entrypoint /usr/local/bin/init-auth

# init-auth configures git credentials from GH_TOKEN at container startup,
# then hands off to entrypoint. Auth is the container's responsibility;
# the entrypoint assumes git is already configured.
ENTRYPOINT ["/usr/local/bin/init-auth"]
