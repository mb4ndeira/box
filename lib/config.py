import os
import tomllib
from dataclasses import dataclass, field
from typing import Optional


class ConfigError(Exception):
    pass


@dataclass
class SshExecutorConfig:
    host: str
    user: Optional[str] = None


@dataclass
class DockerExecutorConfig:
    image: str
    runtime: Optional[str] = None


@dataclass
class OpenCodeProviderConfig:
    model: str
    api_url: str
    api_key: str  # resolved from env


@dataclass
class ClaudeProviderConfig:
    api_key: Optional[str] = None  # defaults to $ANTHROPIC_API_KEY


@dataclass
class RuntimeConfig:
    executor: str  # local | ssh | docker
    provider: str  # claude | opencode
    ssh: Optional[SshExecutorConfig] = None
    docker: Optional[DockerExecutorConfig] = None
    opencode: Optional[OpenCodeProviderConfig] = None
    claude: Optional[ClaudeProviderConfig] = None


@dataclass
class ContextConfig:
    standards: list[str] = field(default_factory=list)
    workspace_map: Optional[str] = None


@dataclass
class ProjectServicesConfig:
    infisical: bool = False


@dataclass
class ProjectContextConfig:
    extra: list[str] = field(default_factory=list)


@dataclass
class ProjectConfig:
    name: str
    path: str
    workers: int = 1
    services: ProjectServicesConfig = field(default_factory=ProjectServicesConfig)
    context: ProjectContextConfig = field(default_factory=ProjectContextConfig)


@dataclass
class BoxConfig:
    runtime: RuntimeConfig
    context: ContextConfig
    projects: list[ProjectConfig]
    _path: str = ""

    def project(self, name: str) -> ProjectConfig:
        for p in self.projects:
            if p.name == name:
                return p
        raise ConfigError(f"project '{name}' not found in box.toml")


def _expand_env(value: str) -> str:
    """Expand ${VAR} patterns in a string."""
    import re
    def replace(m):
        var = m.group(1)
        val = os.environ.get(var)
        if val is None:
            raise ConfigError(f"environment variable ${var} is not set")
        return val
    return re.sub(r"\$\{([^}]+)\}", replace, value)


def load_config(path: str) -> BoxConfig:
    path = os.path.expanduser(path)
    if not os.path.exists(path):
        raise ConfigError(f"config not found: {path}")

    with open(path, "rb") as f:
        raw = tomllib.load(f)

    r = raw.get("runtime", {})
    executor = r.get("executor", "local")
    provider = r.get("provider", "claude")

    ssh = None
    if "executor" in r and "ssh" in r["executor"]:
        s = r["executor"]["ssh"]
        ssh = SshExecutorConfig(host=s["host"], user=s.get("user"))

    docker = None
    if "executor" in r and "docker" in r["executor"]:
        d = r["executor"]["docker"]
        docker = DockerExecutorConfig(image=d["image"], runtime=d.get("runtime"))

    opencode = None
    if "provider" in r and "opencode" in r["provider"]:
        o = r["provider"]["opencode"]
        opencode = OpenCodeProviderConfig(
            model=o["model"],
            api_url=o["api_url"],
            api_key=_expand_env(o["api_key"]),
        )

    claude = None
    if "provider" in r and "claude" in r["provider"]:
        c = r["provider"].get("claude", {})
        claude = ClaudeProviderConfig(api_key=c.get("api_key"))

    runtime = RuntimeConfig(
        executor=executor,
        provider=provider,
        ssh=ssh,
        docker=docker,
        opencode=opencode,
        claude=claude,
    )

    ctx_raw = raw.get("context", {})
    context = ContextConfig(
        standards=[os.path.expanduser(p) for p in ctx_raw.get("standards", [])],
        workspace_map=os.path.expanduser(ctx_raw["workspace_map"])
        if "workspace_map" in ctx_raw
        else None,
    )

    projects = []
    for p in raw.get("projects", []):
        svc_raw = p.get("services", {})
        ctx_extra = p.get("context", {}).get("extra", [])
        projects.append(
            ProjectConfig(
                name=p["name"],
                path=os.path.expanduser(p["path"]),
                workers=p.get("workers", 1),
                services=ProjectServicesConfig(infisical=svc_raw.get("infisical", False)),
                context=ProjectContextConfig(
                    extra=[os.path.expanduser(e) for e in ctx_extra]
                ),
            )
        )

    return BoxConfig(runtime=runtime, context=context, projects=projects, _path=path)
