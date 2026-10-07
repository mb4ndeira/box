"""Show current worker status."""

from config import BoxConfig


def show_status(config: BoxConfig) -> None:
    print(f"executor : {config.runtime.executor}")
    print(f"provider : {config.runtime.provider}")
    print(f"projects : {len(config.projects)}")
    print()
    for p in config.projects:
        print(f"  {p.name:<20}  workers={p.workers}  path={p.path}")
