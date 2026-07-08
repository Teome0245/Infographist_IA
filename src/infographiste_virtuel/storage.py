"""Gestion du stockage distant (S3) pour le mode DISTRIBUTED."""

from __future__ import annotations

from pathlib import Path

from .config import StorageConfig


class StorageManager:
    def __init__(self, config: StorageConfig) -> None:
        self.config = config

    def _s3_key(self, relative: str) -> str:
        prefix = self.config.s3_prefix.strip("/")
        rel = relative.lstrip("/")
        return f"{prefix}/{rel}" if prefix else rel

    def upload_path(self, local_path: Path, remote_relative: str | None = None) -> str:
        if self.config.backend.upper() != "S3":
            raise NotImplementedError(f"Backend stockage non supporté: {self.config.backend}")

        import boto3

        if not self.config.s3_bucket:
            raise ValueError("S3_BUCKET non configuré")

        remote_relative = remote_relative or local_path.name
        key = self._s3_key(remote_relative)
        s3 = boto3.client("s3", region_name=self.config.s3_region)

        if local_path.is_dir():
            for file in local_path.rglob("*"):
                if file.is_file():
                    rel = str(file.relative_to(local_path.parent))
                    s3.upload_file(str(file), self.config.s3_bucket, self._s3_key(rel))
        else:
            s3.upload_file(str(local_path), self.config.s3_bucket, key)

        return f"s3://{self.config.s3_bucket}/{key}"

    def upload_dataset(self, dataset_dir: Path) -> str:
        return self.upload_path(dataset_dir, remote_relative="dataset")

    def upload_lora(self, lora_path: Path) -> str:
        return self.upload_path(lora_path, remote_relative=f"lora/{lora_path.name}")
