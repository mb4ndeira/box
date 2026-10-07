#!/usr/bin/env bash
# Container auth init — runs before entrypoint.
# Configures git credentials from GH_TOKEN, then hands off to the worker.
# This file lives in the container image, not in git history, so it can safely
# reference the GH_TOKEN env var without triggering secret scanning on push.

set -euo pipefail

if [[ -n "${GH_TOKEN:-}" ]]; then
    echo "$GH_TOKEN" | gh auth login --with-token 2>/dev/null || true
    gh auth setup-git 2>/dev/null || true
fi

exec /usr/local/bin/entrypoint "$@"
