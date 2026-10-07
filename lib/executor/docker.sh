#!/usr/bin/env bash
# Executor: docker — run the worker inside a container.
# Each worker clones the repo fresh inside the container — no shared host path mount.
# This is what makes concurrent workers safe: each gets an isolated working copy.

set -euo pipefail

IMAGE="${BOX_DOCKER_IMAGE:?BOX_DOCKER_IMAGE not set}"

# Runtime is optional — fall back silently if the requested one isn't available.
RUNTIME_FLAG=""
if [[ -n "${BOX_DOCKER_RUNTIME:-}" ]]; then
    if docker info --format '{{json .Runtimes}}' 2>/dev/null | grep -q "\"${BOX_DOCKER_RUNTIME}\""; then
        RUNTIME_FLAG="--runtime ${BOX_DOCKER_RUNTIME}"
    else
        echo "box: runtime '${BOX_DOCKER_RUNTIME}' not available on this host, using default" >&2
    fi
fi

# Collect BOX_* env vars as --env flags (values come from the current env)
ENV_FLAGS=()
while IFS='=' read -r key _; do
    ENV_FLAGS+=("--env" "$key")
done < <(env | grep '^BOX_')

# Pass GitHub token for private repo clones
if [[ -n "${BOX_GITHUB_TOKEN:-}" ]]; then
    ENV_FLAGS+=("--env" "BOX_GITHUB_TOKEN")
fi

# Context file is host-side — mount it read-only into the container
CONTEXT_MOUNT=""
if [[ -n "${BOX_CONTEXT_FILE:-}" ]]; then
    CONTEXT_MOUNT="--volume ${BOX_CONTEXT_FILE}:${BOX_CONTEXT_FILE}:ro"
fi

# No project path mount — the worker clones fresh inside the container.
docker run --rm \
    ${RUNTIME_FLAG} \
    "${ENV_FLAGS[@]}" \
    ${CONTEXT_MOUNT} \
    "$IMAGE"
