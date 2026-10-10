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
#   BOX_PROVIDER        claude | opencode | simple
# Optional:
#   BOX_PROJECT_REPO    git clone URL — triggers clone mode
#   BOX_OPENCODE_MODEL, BOX_OPENCODE_API_URL, BOX_OPENCODE_API_KEY
#   OPENCODE_FLAGS      extra opencode run flags
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
    WORK_DIR="${PROJECT_PATH}/box-worker-$(date +%s)"
    mkdir -p "$(dirname "$WORK_DIR")"
    git clone --depth 1 "$BOX_PROJECT_REPO" "$WORK_DIR"
    cd "$WORK_DIR"
else
    cd "$PROJECT_PATH"
fi

# ── Branch ────────────────────────────────────────────────────────────────────

SLUG="$(echo "$TASK" | tr '[:upper:] ' '[:lower:]-' | tr -cd '[:alnum:]-' | cut -c1-40)"
BRANCH="box/$(date +%Y%m%d-%H%M%S)-${SLUG}"
git checkout -b "$BRANCH"

# ── Run provider ──────────────────────────────────────────────────────────────

TASK_MSG="Your task: ${TASK}. Work in $(pwd). Follow all standards in the attached context. When done: commit using conventional commits, then open a PR against main."

TASK_FILE=$(mktemp /tmp/box-task-XXXXXX.md)
printf '%s\n' "$TASK_MSG" > "$TASK_FILE"
trap 'rm -f "$TASK_FILE"' EXIT

case "$PROVIDER" in
    opencode)
        MODEL="${BOX_OPENCODE_MODEL:?}"
        export OPENAI_API_KEY="${BOX_OPENCODE_API_KEY:?}"
        export OPENAI_BASE_URL="${BOX_OPENCODE_API_URL:?}"
        # Generate a project-level opencode config that uses @ai-sdk/openai-compatible
        # (Chat Completions API). The built-in openai provider uses the Responses API
        # which doesn't work with 9router/GLM — tool calls get aborted.
        mkdir -p ~/.config/opencode
        cat > ~/.config/opencode/opencode.jsonc << JSON
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "box-backend": {
      "name": "Box Backend",
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "{env:OPENAI_BASE_URL}",
        "apiKey": "{env:OPENAI_API_KEY}"
      },
      "models": {
        "${MODEL}": {
          "name": "${MODEL}"
        }
      }
    }
  }
}
JSON
        opencode run \
            --model "box-backend/${MODEL}" \
            --dir "$(pwd)" \
            -f "$CONTEXT_FILE" \
            --auto \
            ${OPENCODE_FLAGS:-} \
            "$TASK_FILE"
        ;;
    simple)
        # Lightweight: single curl call to the backend. Useful for chain-testing.
        MODEL="${BOX_OPENCODE_MODEL:?}"
        PAYLOAD=$(jq -n \
            --arg model "$MODEL" \
            --arg msg "$TASK_MSG" \
            '{model: $model, messages: [{role: "user", content: $msg}], max_tokens: 512, stream: false}')
        echo "box: calling ${BOX_OPENCODE_API_URL} with model ${MODEL}"
        curl -sS "${BOX_OPENCODE_API_URL:?}/chat/completions" \
            -H "Authorization: Bearer ${BOX_OPENCODE_API_KEY:?}" \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD" \
            | jq -r '.choices[0].message.content // .error // .'
        ;;
    claude)
        [[ -n "${BOX_CLAUDE_API_KEY:-}" ]] && export ANTHROPIC_API_KEY="${BOX_CLAUDE_API_KEY}"
        claude --print ${CLAUDE_FLAGS:-} "$TASK_MSG"
        ;;
    *)
        echo "box: unknown provider: $PROVIDER" >&2
        exit 1
        ;;
esac

echo "box worker: done"
