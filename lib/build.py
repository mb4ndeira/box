"""Build the worker Docker image from the box repo root."""

import os
import subprocess

BOX_ROOT = os.path.join(os.path.dirname(__file__), "..")
DOCKERFILE = os.path.join(BOX_ROOT, "worker", "Dockerfile")


def build_image(tag: str = "box-worker:latest") -> None:
    root = os.path.realpath(BOX_ROOT)
    print(f"box: building {tag} from {root}")
    subprocess.run(
        ["docker", "build", "-f", DOCKERFILE, "-t", tag, "."],
        cwd=root,
        check=True,
    )
    print(f"box: built {tag}")
