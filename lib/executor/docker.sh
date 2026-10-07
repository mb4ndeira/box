#!/usr/bin/env bash
# Executor: docker — run the worker inside a container.
# Mounts the project path read-write; context file is passed via volume.

set -euo pipefail

IMAGE="${BOX_DOCKER_IMAGE:?BOX_DOCKER_IMAGE not set}"
RUNTIME_FLAG=""
if [[ -n "${BOX_DOCKER_RUNTIME:-}" ]]; then
    RUNTIME_FLAG="--runtime ${BOX_DOCKER_RUNTIME}"
fi

# Collect BOX_* vars as --env flags
ENV_FLAGS=()
while IFS='=' read -r key _; do
    ENV_FLAGS+=("--env" "$key")
done < <(env | grep '^BOX_')

# Mount project path and context file
docker run --rm \
    ${RUNTIME_FLAG} \
    "${ENV_FLAGS[@]}" \
    --volume "${BOX_PROJECT_PATH}:${BOX_PROJECT_PATH}:rw" \
    --volume "${BOX_CONTEXT_FILE}:${BOX_CONTEXT_FILE}:ro" \
    "$IMAGE"
