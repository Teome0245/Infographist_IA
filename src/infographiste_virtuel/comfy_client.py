"""Client HTTP pour l'API ComfyUI."""

from __future__ import annotations

import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import requests
from tenacity import retry, stop_after_attempt, wait_exponential

from .config import InfraConfig


@dataclass
class GeneratedImage:
    filename: str
    subfolder: str
    image_type: str
    local_path: Path


class ComfyUIClient:
    def __init__(self, base_url: str, infra: InfraConfig) -> None:
        self.base_url = base_url.rstrip("/")
        self.infra = infra
        self.session = requests.Session()
        if infra.auth_header and infra.auth_value:
            self.session.headers[infra.auth_header] = infra.auth_value

    def _url(self, path: str) -> str:
        return f"{self.base_url}{path}"

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=1, max=8))
    def submit_prompt(self, workflow: dict[str, Any], client_id: str | None = None) -> str:
        client_id = client_id or str(uuid.uuid4())
        payload = {"prompt": workflow["prompt"], "client_id": client_id}
        resp = self.session.post(
            self._url("/prompt"),
            json=payload,
            timeout=self.infra.request_timeout_s,
        )
        resp.raise_for_status()
        data = resp.json()
        prompt_id = data.get("prompt_id")
        if not prompt_id:
            raise RuntimeError(f"Réponse ComfyUI sans prompt_id: {data}")
        return prompt_id

    def wait_for_completion(self, prompt_id: str) -> dict[str, Any]:
        deadline = time.time() + self.infra.job_timeout_s
        while time.time() < deadline:
            resp = self.session.get(
                self._url(f"/history/{prompt_id}"),
                timeout=self.infra.request_timeout_s,
            )
            resp.raise_for_status()
            history = resp.json()
            if prompt_id in history:
                entry = history[prompt_id]
                status = entry.get("status", {})
                if status.get("completed") or entry.get("outputs"):
                    return entry
                if status.get("status_str") == "error":
                    raise RuntimeError(f"Job ComfyUI en erreur: {entry}")
            time.sleep(self.infra.poll_interval_s)
        raise TimeoutError(
            f"Timeout après {self.infra.job_timeout_s}s pour prompt_id={prompt_id}"
        )

    def download_outputs(
        self,
        history_entry: dict[str, Any],
        output_dir: Path,
    ) -> list[GeneratedImage]:
        output_dir.mkdir(parents=True, exist_ok=True)
        saved: list[GeneratedImage] = []

        outputs = history_entry.get("outputs", {})
        for _node_id, node_output in outputs.items():
            for image in node_output.get("images", []):
                filename = image["filename"]
                subfolder = image.get("subfolder", "")
                image_type = image.get("type", "output")
                params = {
                    "filename": filename,
                    "subfolder": subfolder,
                    "type": image_type,
                }
                resp = self.session.get(
                    self._url("/view"),
                    params=params,
                    timeout=self.infra.request_timeout_s,
                )
                resp.raise_for_status()
                dest = output_dir / filename
                dest.write_bytes(resp.content)
                saved.append(
                    GeneratedImage(
                        filename=filename,
                        subfolder=subfolder,
                        image_type=image_type,
                        local_path=dest,
                    )
                )
        return saved

    def run_workflow(
        self,
        workflow: dict[str, Any],
        output_dir: Path,
    ) -> list[GeneratedImage]:
        prompt_id = self.submit_prompt(workflow)
        print(f"ComfyUI prompt_id={prompt_id} ({self.base_url})")
        history = self.wait_for_completion(prompt_id)
        return self.download_outputs(history, output_dir)
