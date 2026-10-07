#!/usr/bin/env bash
# Executor: remote-docker
# SSHs to the target machine and runs Docker there.
# The target provides container isolation (Kata on Linux, runc elsewhere).
# Dispatch runs anywhere; workers always run on the configured target.

set -euo pipefail

HOST="${BOX_SSH_HOST:?BOX_SSH_HOST not set}"
SSH_TARGET="${BOX_SSH_USER:+${BOX_SSH_USER}@}${HOST}"
IMAGE="${BOX_DOCKER_IMAGE:?BOX_DOCKER_IMAGE not set}"

STAMP="$(date +%s)-$$"
REMOTE_CTX="/tmp/box-context-${STAMP}.md"
REMOTE_ENV="/tmp/box-env-${STAMP}"

# Check whether the requested runtime is available on the target machine.
# Fail silently and use the default runtime if it isn't.
RUNTIME_FLAG=""
if [[ -n "${BOX_DOCKER_RUNTIME:-}" ]]; then
    if ssh -q -o BatchMode=yes "${SSH_TARGET}" \
        "docker info --format '{{json .Runtimes}}' 2>/dev/null | grep -q '\"${BOX_DOCKER_RUNTIME}\"'"; then
        RUNTIME_FLAG="--runtime ${BOX_DOCKER_RUNTIME}"
    else
        echo "box: runtime '${BOX_DOCKER_RUNTIME}' not on ${HOST}, using default" >&2
    fi
fi

# Write an env file for docker --env-file.
# Docker reads KEY=VALUE literally — no shell quoting needed, values may contain spaces.
ENV_FILE=$(mktemp)
env | grep '^BOX_' | grep -v '^BOX_CONTEXT_FILE=' > "${ENV_FILE}"
echo "BOX_CONTEXT_FILE=${REMOTE_CTX}" >> "${ENV_FILE}"
[[ -n "${GH_TOKEN:-}" ]] && echo "GH_TOKEN=${GH_TOKEN}" >> "${ENV_FILE}"

cleanup() {
    rm -f "${ENV_FILE}"
    ssh -q -o BatchMode=yes "${SSH_TARGET}" "rm -f '${REMOTE_CTX}' '${REMOTE_ENV}'" 2>/dev/null || true
}
trap cleanup EXIT

scp -q "${BOX_CONTEXT_FILE}" "${SSH_TARGET}:${REMOTE_CTX}"
scp -q "${ENV_FILE}"         "${SSH_TARGET}:${REMOTE_ENV}"

echo "box: running on ${HOST} via docker"
ssh -o BatchMode=yes "${SSH_TARGET}" \
    "docker run --rm ${RUNTIME_FLAG} --env-file '${REMOTE_ENV}' --volume '${REMOTE_CTX}:${REMOTE_CTX}:ro' '${IMAGE}'"
