#!/usr/bin/env bash
# Executor: local — run the worker directly on the current machine.
# All BOX_* env vars are set by dispatch.py before this script runs.

set -euo pipefail

BOX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKER="${BOX_ROOT}/worker/entrypoint.sh"

exec bash "$WORKER"
