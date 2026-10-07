"""Build the context bundle injected into every worker."""

import os
from config import BoxConfig, ProjectConfig


def build_context(config: BoxConfig, project: ProjectConfig) -> str:
    """Return a single string with all tacit knowledge for the worker."""
    parts = []

    # Global standards
    for path in config.context.standards:
        content = _read_optional(path)
        if content:
            parts.append(f"# {os.path.basename(path)}\n\n{content}")

    # Workspace map
    if config.context.workspace_map:
        content = _read_optional(config.context.workspace_map)
        if content:
            parts.append(f"# Workspace registry (projects.toml)\n\n```toml\n{content}\n```")

    # Project-specific extras
    for path in project.context.extra:
        content = _read_optional(path)
        if content:
            parts.append(f"# {os.path.basename(path)}\n\n{content}")

    return "\n\n---\n\n".join(parts)


def write_context_file(config: BoxConfig, project: ProjectConfig, dest: str) -> None:
    """Write the context bundle to dest so entrypoint.sh can pass it to the worker."""
    bundle = build_context(config, project)
    with open(dest, "w") as f:
        f.write(bundle)


def _read_optional(path: str) -> str:
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        print(f"box: context file not found, skipping: {path}")
        return ""
