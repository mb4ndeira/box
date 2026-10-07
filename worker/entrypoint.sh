#!/usr/bin/env bash
# Worker entrypoint — runs inside the executor (local, SSH, or Docker).
#
# Two modes:
#   clone mode  (BOX_PROJECT_REPO is set)  — clones the repo fresh, works there.
#               Used by the docker executor. Each worker gets an isolated copy;
#               concurrent workers on the same project cannot collide.
#
#   local mode  (no BOX_PROJECT_REPO)      — works in the existing checkout at
#               BOX_PROJECT_PATH. Used by the local and ssh executors. Single
#               worker only; concurrent use on the same repo will conflict.
#
# Expected env:
#   BOX_PROJECT_NAME    project identifier
#   BOX_PROJECT_PATH    absolute path (local mode) or target clone dir (clone mode)
#   BOX_TASK            task description
#   BOX_CONTEXT_FILE    path to the assembled context bundle
#   BOX_PROVIDER        claude | opencode
# Optional:
#   BOX_PROJECT_REPO    git clone URL — triggers clone mode
#   BOX_GITHUB_TOKEN    token for private repo clones (HTTPS)
#   BOX_OPENCODE_MODEL, BOX_OPENCODE_API_URL, BOX_OPENCODE_API_KEY
#   OPENCODE_FLAGS      extra opencode run flags (e.g. "--auto")
#   CLAUDE_FLAGS        extra claude flags

set -euo pipefail

PROJECT_NAME="${BOX_PROJECT_NAME:?}"
PROJECT_PATH="${BOX_PROJECT_PATH:?}"
TASK="${BOX_TASK:?}"
CONTEXT_FILE="${BOX_CONTEXT_FILE:?}"
PROVIDER="${BOX_PROVIDER:-claude}"

echo "box worker: ${PROJECT_NAME} — ${TASK}"

# ── Prepare working directory ─────────────────────────────────────────────────

if [[ -n "${BOX_PROJECT_REPO:-}" ]]; then
    # Clone mode: fresh isolated copy inside this executor environment
    WORK_DIR="${PROJECT_PATH}/box-worker-$(date +%s)"
    mkdir -p "$(dirname "$WORK_DIR")"

    CLONE_OPTS=()
    if [[ -n "${BOX_GITHUB_TOKEN:-}" ]]; then
        # Use a credential header so the token never appears in any URL
        CLONE_OPTS+=(-c "http.extraHeader=Authorization: token ${BOX_GITHUB_TOKEN}")
    fi

    git clone --depth 1 "${CLONE_OPTS[@]}" "$BOX_PROJECT_REPO" "$WORK_DIR"
    cd "$WORK_DIR"
else
    # Local mode: use existing checkout
    cd "$PROJECT_PATH"
fi

# ── Branch ────────────────────────────────────────────────────────────────────

SLUG="$(echo "$TASK" | tr '[:upper:] ' '[:lower:]-' | tr -cd '[:alnum:]-' | cut -c1-40)"
BRANCH="box/$(date +%Y%m%d-%H%M%S)-${SLUG}"
git checkout -b "$BRANCH"

# ── Run provider ──────────────────────────────────────────────────────────────

TASK_MSG="Your task: ${TASK}. Work in $(pwd). Follow all standards in the attached context. When done: commit using conventional commits, then open a PR against main."

case "$PROVIDER" in
    opencode)
        export OPENAI_BASE_URL="${BOX_OPENCODE_API_URL:?}"
        export OPENAI_API_KEY="${BOX_OPENCODE_API_KEY:?}"
        opencode run \
            --model "${BOX_OPENCODE_MODEL:?}" \
            --dir "$(pwd)" \
            -f "$CONTEXT_FILE" \
            ${OPENCODE_FLAGS:-} \
            "$TASK_MSG"
        ;;
    claude)
        claude ${CLAUDE_FLAGS:-} --print "$TASK_MSG"
        ;;
    *)
        echo "box: unknown provider: $PROVIDER" >&2
        exit 1
        ;;
esac

echo "box worker: done"
