#!/usr/bin/env bash
# Executor: ssh — run the worker on BOX_SSH_HOST.
# The remote machine must have box cloned at ~/workspace/box or equivalent.
# All BOX_* env vars are forwarded via SSH SendEnv / inline export.

set -euo pipefail

HOST="${BOX_SSH_HOST:?BOX_SSH_HOST not set}"
USER_PREFIX=""
if [[ -n "${BOX_SSH_USER:-}" ]]; then
    USER_PREFIX="${BOX_SSH_USER}@"
fi

# Build an env export string for the remote session.
REMOTE_ENV=$(env | grep '^BOX_' | sed "s/'/'\\\\''/g" | sed "s/^/export '/;s/$/'/" | tr '\n' ';')
WORKER_PATH="$(ssh "${USER_PREFIX}${HOST}" 'echo $HOME')/workspace/box/worker/entrypoint.sh"

ssh -o BatchMode=yes "${USER_PREFIX}${HOST}" "
    ${REMOTE_ENV}
    bash ${WORKER_PATH}
"
