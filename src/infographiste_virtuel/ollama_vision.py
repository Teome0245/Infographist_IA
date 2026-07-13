"""Client minimal Ollama (vision) sans dépendances externes.

API utilisée:
- POST /api/tags (optionnel) pour lister les modèles
- POST /api/generate pour classification (images base64)
"""

from __future__ import annotations

import base64
import json
import os
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any


@dataclass
class OllamaConfig:
    base_url: str
    model: str
    timeout_s: float = 60.0


def ollama_config_from_env() -> OllamaConfig:
    base = os.environ.get("OLLAMA_BASE_URL", "http://192.168.0.110:11434").rstrip("/")
    model = os.environ.get("OLLAMA_VISION_MODEL", "llava").strip()
    try:
        timeout_s = float(os.environ.get("OLLAMA_TIMEOUT_S", "60"))
    except ValueError:
        timeout_s = 60.0
    return OllamaConfig(base_url=base, model=model, timeout_s=timeout_s)


def _post_json(url: str, payload: dict[str, Any], *, timeout_s: float) -> dict[str, Any]:
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout_s) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:  # pragma: no cover
        raw = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Ollama HTTP {e.code}: {raw[:400]}") from e
    except (urllib.error.URLError, TimeoutError) as e:  # pragma: no cover
        raise RuntimeError(f"Ollama unreachable: {e}") from e
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:  # pragma: no cover
        raise RuntimeError(f"Ollama JSON invalide: {raw[:400]}") from e
    if not isinstance(data, dict):
        raise RuntimeError("Ollama réponse non-dict")
    return data


def list_models(cfg: OllamaConfig) -> list[str]:
    # /api/tags renvoie {"models":[{"name": "..."}]}
    data = _post_json(f"{cfg.base_url}/api/tags", {}, timeout_s=cfg.timeout_s)
    models = data.get("models")
    if not isinstance(models, list):
        return []
    out: list[str] = []
    for m in models:
        if isinstance(m, dict) and isinstance(m.get("name"), str):
            out.append(m["name"])
    return out


def _read_image_b64(path: str) -> str:
    raw = open(path, "rb").read()
    return base64.b64encode(raw).decode("ascii")


def generate(cfg: OllamaConfig, *, prompt: str, image_path: str) -> str:
    payload = {
        "model": cfg.model,
        "prompt": prompt,
        "stream": False,
        "format": "json",
        "images": [_read_image_b64(image_path)],
    }
    data = _post_json(f"{cfg.base_url}/api/generate", payload, timeout_s=cfg.timeout_s)
    # "response" contient du texte JSON si format=json
    resp = data.get("response")
    if not isinstance(resp, str):
        raise RuntimeError("Ollama réponse sans champ 'response'")
    return resp.strip()

