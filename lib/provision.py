"""Provision services before a worker runs."""

import os
import subprocess
from config import BoxConfig, ConfigError

PROVISION_DIR = os.path.join(os.path.dirname(__file__), "provision")


def provision_project(config: BoxConfig, project_name: str) -> None:
    project = config.project(project_name)
    svc = project.services

    if svc.infisical:
        _run_provision("infisical.sh", project.path)


def _run_provision(script_name: str, project_path: str) -> None:
    script = os.path.join(PROVISION_DIR, script_name)
    if not os.path.exists(script):
        raise ConfigError(f"provision script not found: {script}")
    subprocess.run(
        ["bash", script],
        env={**os.environ, "PROJECT_PATH": project_path},
        check=True,
    )
