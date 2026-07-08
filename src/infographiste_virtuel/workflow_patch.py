"""Injection dynamique du prompt et du LoRA dans un workflow ComfyUI (API format)."""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any

PROMPT_CLASS_TYPES = {
    "CLIPTextEncode",
    "CLIPTextEncodeFlux",
    "TextEncode",
}
LORA_CLASS_TYPES = {
    "LoraLoader",
    "LoraLoaderModelOnly",
    "LoraLoader|pysssss",
}


def load_workflow(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as fh:
        data = json.load(fh)

    if "prompt" not in data:
        raise ValueError(f"Workflow invalide (clé 'prompt' manquante): {path}")
    return data


def _iter_nodes(prompt: dict[str, Any]) -> list[tuple[str, dict[str, Any]]]:
    return [(node_id, node) for node_id, node in prompt.items() if isinstance(node, dict)]


def patch_workflow(
    workflow: dict[str, Any],
    *,
    prompt_text: str | None = None,
    lora_name: str | None = None,
    prompt_nodes: list[str] | None = None,
    negative_nodes: list[str] | None = None,
    lora_nodes: list[str] | None = None,
    negative_prompt: str | None = None,
    seed: int | None = None,
) -> dict[str, Any]:
    patched = copy.deepcopy(workflow)
    prompt: dict[str, Any] = patched["prompt"]

    explicit_prompt_nodes = set(prompt_nodes or [])
    explicit_negative_nodes = set(negative_nodes or [])
    explicit_lora_nodes = set(lora_nodes or [])

    for node_id, node in _iter_nodes(prompt):
        class_type = node.get("class_type", "")
        inputs = node.setdefault("inputs", {})

        if prompt_text and node_id in explicit_prompt_nodes and "text" in inputs:
            inputs["text"] = prompt_text
        elif prompt_text and not explicit_prompt_nodes and class_type in PROMPT_CLASS_TYPES:
            title = str(node.get("_meta", {}).get("title", "")).lower()
            if "negative" not in title and "text" in inputs:
                inputs["text"] = prompt_text

        if negative_prompt and node_id in explicit_negative_nodes and "text" in inputs:
            inputs["text"] = negative_prompt
        elif negative_prompt and not explicit_negative_nodes and class_type in PROMPT_CLASS_TYPES:
            title = str(node.get("_meta", {}).get("title", "")).lower()
            if "negative" in title and "text" in inputs:
                inputs["text"] = negative_prompt

        if lora_name and (
            node_id in explicit_lora_nodes
            or (not explicit_lora_nodes and class_type in LORA_CLASS_TYPES)
        ):
            if "lora_name" in inputs:
                inputs["lora_name"] = lora_name

        if seed is not None and class_type in {"KSampler", "KSamplerAdvanced", "SamplerCustom"}:
            if "seed" in inputs:
                inputs["seed"] = seed

    return patched
