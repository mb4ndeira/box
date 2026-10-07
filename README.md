# box

Library for building agentic coding factories. Dispatch tasks to workers running locally, over SSH, or in containers.

## Install

```bash
pip install -e /path/to/box
# or just symlink bin/box onto your PATH
ln -sf ~/workspace/box/bin/box ~/.local/bin/box
```

## Usage

```bash
box dispatch scheduler "add cron expression validation"
box dispatch cinco_chat "migrate users table to use uuid" --dry-run
box status
box provision cinco_chat
```

## Configuration

`box` reads `~/workspace/factory/box.toml` by default. Override with `--config`:

```bash
box --config /path/to/box.toml dispatch ...
```

See `box.toml.example` for the full schema.

## Executors

| Executor | When to use |
|---|---|
| `local` | Mac or any machine where you want the worker to run in-process |
| `ssh` | Delegate to a remote machine (e.g. korora) over SSH |
| `docker` | Isolated container; set `runtime = "kata"` for VM-level sandboxing |

## How it works

1. `box dispatch` reads `box.toml`, finds the project, writes a context bundle (tacit knowledge from `[context].standards`).
2. The selected executor script (`lib/executor/<name>.sh`) runs.
3. The executor calls `worker/entrypoint.sh` with `BOX_*` env vars.
4. The worker: creates a branch, builds a prompt (context + task), runs the provider (claude or opencode), then commits and opens a PR.

## Context injection

Workers receive a bundle of tacit knowledge before the task. Configure in `box.toml`:

```toml
[context]
standards = [
    "~/workspace/agents/docs/standards/coding.md",
    "~/workspace/agents/docs/standards/prose.md",
]
workspace_map = "~/workspace/agents/docs/workspace/projects.toml"
```

Missing files are skipped with a warning — no hard failure.
