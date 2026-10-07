#!/usr/bin/env bash
# Worker entrypoint — runs inside the executor (local, SSH, or Docker).
# Expected env:
#   BOX_PROJECT_NAME   — project identifier
#   BOX_PROJECT_PATH   — absolute path to the project
#   BOX_TASK           — task description
#   BOX_CONTEXT_FILE   — path to the assembled context bundle (markdown)
#   BOX_PROVIDER       — claude | opencode
# Optional:
#   BOX_OPENCODE_MODEL, BOX_OPENCODE_API_URL, BOX_OPENCODE_API_KEY

set -euo pipefail

PROJECT_NAME="${BOX_PROJECT_NAME:?}"
PROJECT_PATH="${BOX_PROJECT_PATH:?}"
TASK="${BOX_TASK:?}"
CONTEXT_FILE="${BOX_CONTEXT_FILE:?}"
PROVIDER="${BOX_PROVIDER:-claude}"

echo "box worker: ${PROJECT_NAME} — ${TASK}"

cd "$PROJECT_PATH"

# Create a dedicated branch for this task
SLUG="$(echo "$TASK" | tr '[:upper:] ' '[:lower:]-' | tr -cd '[:alnum:]-' | cut -c1-40)"
BRANCH="box/$(date +%Y%m%d-%H%M%S)-${SLUG}"
git checkout -b "$BRANCH"

# Build the full prompt: context bundle + task
CONTEXT="$(cat "$CONTEXT_FILE")"
PROMPT="${CONTEXT}

---

# Task

${TASK}

Work in ${PROJECT_PATH}. Follow all standards above.
When done: commit using conventional commits, then open a PR against main."

case "$PROVIDER" in
    opencode)
        export OPENAI_BASE_URL="${BOX_OPENCODE_API_URL:?}"
        export OPENAI_API_KEY="${BOX_OPENCODE_API_KEY:?}"
        opencode run --model "${BOX_OPENCODE_MODEL:?}" --message "$PROMPT"
        ;;
    claude)
        # Pass --print for non-interactive mode; add permission flags in your
        # factory's instance config or via CLAUDE_FLAGS env var.
        claude ${CLAUDE_FLAGS:-} --print "$PROMPT"
        ;;
    *)
        echo "box: unknown provider: $PROVIDER" >&2
        exit 1
        ;;
esac

echo "box worker: done"
