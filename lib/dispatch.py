"""Resolve executor and run a task."""

import os
import subprocess
import tempfile
from config import BoxConfig, ConfigError
from context import write_context_file

EXECUTORS = os.path.join(os.path.dirname(__file__), "executor")


def dispatch_task(config: BoxConfig, project_name: str, task: str, dry_run: bool = False) -> None:
    project = config.project(project_name)
    # BOX_EXECUTOR env var overrides config — useful for switching without editing box.toml
    executor = os.environ.get("BOX_EXECUTOR") or config.runtime.executor

    script = os.path.join(EXECUTORS, f"{executor}.sh")
    if not os.path.exists(script):
        raise ConfigError(f"unknown executor: {executor}")

    with tempfile.NamedTemporaryFile(mode="w", suffix=".md", delete=False, prefix="box-context-") as f:
        context_file = f.name

    try:
        write_context_file(config, project, context_file)
        env = _build_env(config, project, task, context_file, executor)

        if dry_run:
            print(f"[dry-run] executor: {executor}")
            print(f"[dry-run] project:  {project.name}  ({project.path})")
            print(f"[dry-run] task:     {task}")
            print(f"[dry-run] env:")
            for k, v in sorted(env.items()):
                display = "<redacted>" if "KEY" in k or "TOKEN" in k or "SECRET" in k else v
                print(f"           {k}={display}")
            return

        print(f"box: dispatching '{task}' on {project.name} via {executor}")
        subprocess.run(["bash", script], env={**os.environ, **env}, check=True)

    finally:
        os.unlink(context_file)


def _build_env(config: BoxConfig, project, task: str, context_file: str, executor: str) -> dict:
    env = {
        "BOX_PROJECT_NAME": project.name,
        "BOX_PROJECT_PATH": project.path,
        "BOX_TASK":         task,
        "BOX_CONTEXT_FILE": context_file,
        "BOX_PROVIDER":     config.runtime.provider,
        "BOX_EXECUTOR":     executor,
    }

    if executor == "ssh" and config.runtime.ssh:
        env["BOX_SSH_HOST"] = config.runtime.ssh.host
        if config.runtime.ssh.user:
            env["BOX_SSH_USER"] = config.runtime.ssh.user

    if executor == "docker" and config.runtime.docker:
        env["BOX_DOCKER_IMAGE"]   = config.runtime.docker.image
        if config.runtime.docker.runtime:
            env["BOX_DOCKER_RUNTIME"] = config.runtime.docker.runtime

    if config.runtime.provider == "opencode" and config.runtime.opencode:
        env["BOX_OPENCODE_MODEL"]   = config.runtime.opencode.model
        env["BOX_OPENCODE_API_URL"] = config.runtime.opencode.api_url
        env["BOX_OPENCODE_API_KEY"] = config.runtime.opencode.api_key

    return env
