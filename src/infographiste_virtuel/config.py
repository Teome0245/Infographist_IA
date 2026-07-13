"""Chargement de la configuration (YAML + variables d'environnement)."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

try:
    from dotenv import load_dotenv
except ImportError:  # classify/scan sans venv ComfyUI

    def load_dotenv(*_args: object, **_kwargs: object) -> bool:
        return False

PROJECT_ROOT = Path(__file__).resolve().parents[2]


def _project_root() -> Path:
    return PROJECT_ROOT


def _default_dataset_dir() -> Path:
    return PROJECT_ROOT / "dataset" / "inspiration_mmorpg"


DEFAULT_CONFIG_PATH = PROJECT_ROOT / "config" / "config.yaml"


@dataclass
class InfraTarget:
    base_url: str


@dataclass
class InfraConfig:
    mode: str
    local_url: str
    remote_targets: dict[str, InfraTarget]
    request_timeout_s: int
    poll_interval_s: int
    job_timeout_s: int
    auth_header: str | None = None
    auth_value: str | None = None


@dataclass
class StorageConfig:
    backend: str
    s3_bucket: str
    s3_prefix: str
    s3_region: str


@dataclass
class WorkflowConfig:
    prompt_nodes: list[str] = field(default_factory=list)
    negative_nodes: list[str] = field(default_factory=list)
    lora_nodes: list[str] = field(default_factory=list)


@dataclass
class AppConfig:
    project_root: Path
    assets_dir: Path
    dataset_dir: Path
    workflows_dir: Path
    local_lora_dir: Path
    infra: InfraConfig
    storage: StorageConfig
    workflow: WorkflowConfig

    def comfy_base_url(self) -> str:
        if self.infra.mode.upper() == "DISTRIBUTED":
            target = os.getenv("INFRA_TARGET", "110")
            remote = self.infra.remote_targets.get(target)
            if remote is None:
                raise ValueError(f"INFRA_TARGET inconnu: {target}")
            return remote.base_url.rstrip("/")
        return self.infra.local_url.rstrip("/")


def _resolve_path(root: Path, value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else (root / path)


def load_config(config_path: Path | None = None, env_path: Path | None = None) -> AppConfig:
    root = PROJECT_ROOT
    env_file = env_path or (root / ".env")
    if env_file.exists():
        load_dotenv(env_file)

    cfg_path = config_path or DEFAULT_CONFIG_PATH
    with cfg_path.open("r", encoding="utf-8") as fh:
        raw: dict[str, Any] = yaml.safe_load(fh) or {}

    project = raw.get("project", {})
    infra_raw = raw.get("infra", {})
    storage_raw = raw.get("storage", {})
    workflow_raw = raw.get("workflow", {})
    lora_raw = raw.get("lora", {})

    mode = os.getenv("INFRA_MODE", infra_raw.get("mode", "LOCAL")).upper()
    local_block = infra_raw.get("local", {})
    dist_block = infra_raw.get("distributed", {})

    local_url = os.getenv("COMFY_LOCAL_URL", local_block.get("base_url", "http://127.0.0.1:8188"))

    remote_targets: dict[str, InfraTarget] = {}
    for key, target in dist_block.get("targets", {}).items():
        env_key = f"COMFY_REMOTE_URL_{key}"
        url = os.getenv(env_key, target.get("base_url", ""))
        remote_targets[str(key)] = InfraTarget(base_url=url)

    if mode == "DISTRIBUTED":
        timeout_block = dist_block
    else:
        timeout_block = local_block

    infra = InfraConfig(
        mode=mode,
        local_url=local_url,
        remote_targets=remote_targets,
        request_timeout_s=int(
            os.getenv("COMFY_REQUEST_TIMEOUT_S", timeout_block.get("request_timeout_s", 30))
        ),
        poll_interval_s=int(
            os.getenv("COMFY_POLL_INTERVAL_S", timeout_block.get("poll_interval_s", 2))
        ),
        job_timeout_s=int(
            os.getenv("COMFY_JOB_TIMEOUT_S", timeout_block.get("job_timeout_s", 1800))
        ),
        auth_header=os.getenv("COMFY_AUTH_HEADER"),
        auth_value=os.getenv("COMFY_AUTH_VALUE"),
    )

    storage = StorageConfig(
        backend=os.getenv("STORAGE_BACKEND", storage_raw.get("backend", "S3")),
        s3_bucket=os.getenv("S3_BUCKET", storage_raw.get("s3", {}).get("bucket", "")),
        s3_prefix=os.getenv("S3_PREFIX", storage_raw.get("s3", {}).get("prefix", "infographiste-virtuel")),
        s3_region=os.getenv("AWS_REGION", storage_raw.get("s3", {}).get("region", "eu-west-3")),
    )

    return AppConfig(
        project_root=root,
        assets_dir=_resolve_path(root, os.getenv("ASSETS_DIR", project.get("assets_dir", "assets/images"))),
        dataset_dir=_resolve_path(root, os.getenv("DATASET_DIR", project.get("dataset_dir", "dataset"))),
        workflows_dir=_resolve_path(root, project.get("workflows_dir", "workflows")),
        local_lora_dir=_resolve_path(root, os.getenv("LOCAL_LORA_DIR", lora_raw.get("local_lora_dir", "lora"))),
        infra=infra,
        storage=storage,
        workflow=WorkflowConfig(
            prompt_nodes=list(workflow_raw.get("prompt_nodes", [])),
            negative_nodes=list(workflow_raw.get("negative_nodes", [])),
            lora_nodes=list(workflow_raw.get("lora_nodes", [])),
        ),
    )
