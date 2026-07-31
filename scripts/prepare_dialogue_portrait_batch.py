#!/usr/bin/env python3
"""Prépare les prompts portrait dialogue (briefs artistiques .art.json)."""

from __future__ import annotations

import json
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[1]
CHAR_DIR = PROJECT_DIR / "pipelines/portraits/characters"
BASE_PROMPT = (PROJECT_DIR / "pipelines/portraits/prompts/portrait_base.txt").read_text(
    encoding="utf-8"
).strip()
EXPRESSIONS = json.loads(
    (PROJECT_DIR / "pipelines/portraits/prompts/expressions.json").read_text(encoding="utf-8")
)
EXPRESSION_NEGATIVES = json.loads(
    (
        PROJECT_DIR / "pipelines/portraits/prompts/expression_negatives.json"
    ).read_text(encoding="utf-8")
)
# Décalage de seed par expression : même identité costume, visage plus mobile.
EXPRESSION_SEED_OFFSET: dict[str, int] = {
    "neutral": 0,
    "happy": 5,
    "angry": 10,
    "sad": 15,
    "surprised": 20,
    "determined": 25,
    "neutral_blink": 30,
    "talk_1": 35,
    "talk_2": 40,
}
FALLBACK_CHARACTERS = json.loads(
    (PROJECT_DIR / "pipelines/portraits/characters_mvp.json").read_text(encoding="utf-8")
)

OUT_ROOT = PROJECT_DIR / "tmp/dialogue_portraits_mvp"
DEFAULT_NEGATIVE = (
    "blurry, low quality, deformed face, asymmetrical eyes, bad anatomy, bad hands, "
    "extra fingers, cropped head, plastic skin, waxy skin, anime, manga, chibi, "
    "watermark, text, logo, busy background, multiple faces"
)


def _load_character_configs() -> list[dict]:
    configs: list[dict] = []
    for path in sorted(CHAR_DIR.glob("*.art.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        if data.get("character_id"):
            configs.append(data)
    if configs:
        return configs
    for char_id, cfg in (FALLBACK_CHARACTERS.get("characters") or {}).items():
        configs.append(
            {
                "character_id": char_id,
                "description": str(cfg.get("description", "")).strip(),
                "expressions": cfg.get("expressions") or [],
            }
        )
    return configs


def build_prompt(cfg: dict, expression: str) -> str:
    suffix = str(EXPRESSIONS.get(expression, "")).strip()
    if cfg.get("identity_lock"):
        parts = [
            "mmorpg_insp",
            BASE_PROMPT,
            str(cfg.get("identity_lock", "")).strip(),
            str(cfg.get("framing", "")).strip(),
        ]
        if expression != "neutral":
            parts.append(
                "same character same costume, keep face identity, "
                "facial expression must change clearly and be readable in small UI"
            )
        parts.append(suffix)
    else:
        parts = [BASE_PROMPT, str(cfg.get("description", "")).strip(), suffix]
    return ", ".join(p for p in parts if p).strip().strip(",")


def build_negative(cfg: dict, expression: str) -> str:
    extra = str(cfg.get("negative_extra", "")).strip()
    expr_neg = str(EXPRESSION_NEGATIVES.get(expression, "")).strip()
    parts = [DEFAULT_NEGATIVE]
    if extra:
        parts.append(extra)
    if expr_neg:
        parts.append(expr_neg)
    return ", ".join(parts)


def seed_for_expression(base_seed: int, expression: str) -> int:
    return int(base_seed) + int(EXPRESSION_SEED_OFFSET.get(expression, 0))


def main() -> int:
    OUT_ROOT.mkdir(parents=True, exist_ok=True)
    manifest_jobs: list[dict] = []
    for cfg in _load_character_configs():
        char_id = str(cfg["character_id"])
        out_dir = OUT_ROOT / char_id
        out_dir.mkdir(parents=True, exist_ok=True)
        expressions = cfg.get("expressions") or []
        base_seed = int(cfg.get("seed", 88000))
        summary = {
            "character_id": char_id,
            "label": cfg.get("label", char_id),
            "seed": base_seed,
            "lora": cfg.get("lora", "mmorpg_insp_lora.safetensors"),
            "art_notes_fr": cfg.get("art_notes_fr", ""),
            "palette": cfg.get("palette", ""),
            "expressions": expressions,
            "export_target": f"prime-client/assets/ui/portraits/{char_id}/",
        }
        (out_dir / "_summary.json").write_text(
            json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        for expression in expressions:
            prompt = build_prompt(cfg, expression)
            negative = build_negative(cfg, expression)
            job_seed = seed_for_expression(base_seed, expression)
            (out_dir / f"{expression}.prompt.txt").write_text(prompt + "\n", encoding="utf-8")
            (out_dir / f"{expression}.negative.txt").write_text(negative + "\n", encoding="utf-8")
            manifest_jobs.append(
                {
                    "character_id": char_id,
                    "expression": expression,
                    "prompt_file": str(out_dir / f"{expression}.prompt.txt"),
                    "negative_file": str(out_dir / f"{expression}.negative.txt"),
                    "seed": job_seed,
                    "lora": summary["lora"],
                }
            )
    (OUT_ROOT / "_batch_jobs.json").write_text(
        json.dumps(manifest_jobs, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Lot portraits préparé dans {OUT_ROOT} ({len(manifest_jobs)} jobs)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
