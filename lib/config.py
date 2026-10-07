import os
import tomllib
from dataclasses import dataclass, field
from typing import Optional


class ConfigError(Exception):
    pass


@dataclass
class TargetConfig:
    name: str
    host: str
    user: Optional[str] = None


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
    api_key: str


@dataclass
class ClaudeProviderConfig:
    api_key: Optional[str] = None


@dataclass
class RuntimeConfig:
    executor: str           # local | docker | remote-docker | ssh
    provider: str           # claude | opencode
    target: Optional[str] = None  # logical name resolved from targets.toml
    ssh: Optional[SshExecutorConfig] = None      # backward compat; prefer target
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
    repo: Optional[str] = None
    workers: int = 1
    services: ProjectServicesConfig = field(default_factory=ProjectServicesConfig)
    context: ProjectContextConfig = field(default_factory=ProjectContextConfig)


@dataclass
class BoxConfig:
    runtime: RuntimeConfig
    context: ContextConfig
    projects: list[ProjectConfig]
    targets: dict[str, TargetConfig] = field(default_factory=dict)
    _path: str = ""

    def project(self, name: str) -> ProjectConfig:
        for p in self.projects:
            if p.name == name:
                return p
        raise ConfigError(f"project '{name}' not found in box.toml")

    def resolve_target(self) -> Optional[TargetConfig]:
        """Return the TargetConfig for runtime.target, or None if no target is set."""
        if not self.runtime.target:
            return None
        t = self.targets.get(self.runtime.target)
        if t is None:
            raise ConfigError(
                f"target '{self.runtime.target}' not found in targets.toml — "
                f"copy targets.toml.example and fill in the host"
            )
        return t

    def ssh_host(self) -> tuple[str, Optional[str]]:
        """Return (host, user) for SSH-based executors."""
        target = self.resolve_target()
        if target:
            return target.host, target.user
        if self.runtime.ssh:
            return self.runtime.ssh.host, self.runtime.ssh.user
        raise ConfigError(
            "no SSH target configured — set runtime.target in box.toml "
            "and define it in targets.toml, or set [runtime.ssh] host"
        )


def _expand_env(value: str) -> str:
    import re
    def replace(m):
        var = m.group(1)
        val = os.environ.get(var)
        if val is None:
            raise ConfigError(f"environment variable ${var} is not set")
        return val
    return re.sub(r"\$\{([^}]+)\}", replace, value)


def _load_targets(box_toml_path: str) -> dict[str, TargetConfig]:
    targets_path = os.path.join(os.path.dirname(box_toml_path), "targets.toml")
    if not os.path.exists(targets_path):
        return {}
    with open(targets_path, "rb") as f:
        raw = tomllib.load(f)
    result = {}
    for name, t in raw.get("targets", {}).items():
        result[name] = TargetConfig(name=name, host=t["host"], user=t.get("user"))
    return result


def load_config(path: str) -> BoxConfig:
    path = os.path.expanduser(path)
    if not os.path.exists(path):
        raise ConfigError(f"config not found: {path}")

    with open(path, "rb") as f:
        raw = tomllib.load(f)

    r = raw.get("runtime", {})
    executor = r.get("executor", "local")
    provider = r.get("provider", "claude")
    target   = r.get("target")

    ssh = None
    if "ssh" in r:
        s = r["ssh"]
        ssh = SshExecutorConfig(host=s["host"], user=s.get("user"))

    docker = None
    if "docker" in r:
        d = r["docker"]
        docker = DockerExecutorConfig(image=d["image"], runtime=d.get("runtime"))

    opencode = None
    if "opencode" in r and provider == "opencode":
        o = r["opencode"]
        opencode = OpenCodeProviderConfig(
            model=o["model"],
            api_url=o["api_url"],
            api_key=_expand_env(o["api_key"]),
        )

    claude = None
    if "claude" in r and provider == "claude":
        raw_key = r["claude"].get("api_key")
        claude = ClaudeProviderConfig(api_key=_expand_env(raw_key) if raw_key else None)

    runtime = RuntimeConfig(
        executor=executor,
        provider=provider,
        target=target,
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
                repo=p.get("repo"),
                workers=p.get("workers", 1),
                services=ProjectServicesConfig(infisical=svc_raw.get("infisical", False)),
                context=ProjectContextConfig(
                    extra=[os.path.expanduser(e) for e in ctx_extra]
                ),
            )
        )

    targets = _load_targets(path)

    return BoxConfig(runtime=runtime, context=context, projects=projects, targets=targets, _path=path)
