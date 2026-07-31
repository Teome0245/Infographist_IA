"""Client minimal Ollama (vision) sans dépendances externes.

API utilisée:
- GET /api/tags pour lister les modèles
- POST /api/generate pour classification (images base64)

Par défaut : Ollama **local** sur le poste GPU (.10 / WSL), pas la VM 110.
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
    keep_alive: str = "30s"


def ollama_config_from_env() -> OllamaConfig:
    # Local GPU (.10) — ne plus saturer 110 (CPU) avec llava
    base = os.environ.get("OLLAMA_BASE_URL", "http://127.0.0.1:11434").rstrip("/")
    # llava-phi3: classifie vraiment (moondream echo souvent le 1er style_id)
    model = os.environ.get("OLLAMA_VISION_MODEL", "llava-phi3").strip()
    try:
        timeout_s = float(os.environ.get("OLLAMA_TIMEOUT_S", "120"))
    except ValueError:
        timeout_s = 120.0
    keep_alive = os.environ.get("OLLAMA_KEEP_ALIVE", "30s").strip() or "30s"
    return OllamaConfig(base_url=base, model=model, timeout_s=timeout_s, keep_alive=keep_alive)


def _http_json(url: str, payload: dict[str, Any] | None = None, *, timeout_s: float) -> dict[str, Any]:
    if payload is None:
        req = urllib.request.Request(url, method="GET")
    else:
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
    data = _http_json(f"{cfg.base_url}/api/tags", timeout_s=cfg.timeout_s)
    models = data.get("models")
    if not isinstance(models, list):
        return []
    out: list[str] = []
    for m in models:
        if isinstance(m, dict) and isinstance(m.get("name"), str):
            out.append(m["name"])
    return out


def _read_image_b64(path: str) -> str:
    """Lit l'image ; redimensionne pour accélérer la vision CPU (1050 Ti / WSL)."""
    max_side = 512
    try:
        max_side = int(os.environ.get("OLLAMA_VISION_MAX_SIDE", "512"))
    except ValueError:
        max_side = 512
    try:
        from PIL import Image
        import io

        with Image.open(path) as im:
            im = im.convert("RGB")
            im.thumbnail((max_side, max_side))
            buf = io.BytesIO()
            im.save(buf, format="JPEG", quality=85)
            return base64.b64encode(buf.getvalue()).decode("ascii")
    except Exception:
        raw = open(path, "rb").read()
        return base64.b64encode(raw).decode("ascii")


def generate(cfg: OllamaConfig, *, prompt: str, image_path: str) -> str:
    try:
        num_predict = int(os.environ.get("OLLAMA_VISION_NUM_PREDICT", "96"))
    except ValueError:
        num_predict = 96
    payload: dict[str, Any] = {
        "model": cfg.model,
        "prompt": prompt,
        "stream": False,
        "format": "json",
        "images": [_read_image_b64(image_path)],
        "keep_alive": cfg.keep_alive,
        "options": {
            "num_predict": num_predict,
            "temperature": 0.0,
        },
    }
    # format=json pousse parfois moondream à boucler sur les clés → parsing robuste côté client
    if os.environ.get("OLLAMA_VISION_FORMAT_JSON", "1").strip() not in ("0", "false", "no"):
        payload["format"] = "json"
    data = _http_json(f"{cfg.base_url}/api/generate", payload, timeout_s=cfg.timeout_s)
    resp = data.get("response")
    if not isinstance(resp, str):
        raise RuntimeError("Ollama réponse sans champ 'response'")
    return resp.strip()
