#!/usr/bin/env python3
"""Lance la génération ComfyUI pour un lot de portraits dialogue préparé."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[1]
BATCH_ROOT = PROJECT_DIR / "tmp/dialogue_portraits_mvp"
OUTPUT_ROOT = PROJECT_DIR / "pipelines/portraits/outputs/mvp"
WORKFLOW = PROJECT_DIR / "workflows/workflow_sd15_lora_refined.json"


def _load_jobs(character_filter: str | None) -> list[dict]:
    jobs_path = BATCH_ROOT / "_batch_jobs.json"
    if not jobs_path.exists():
        raise SystemExit(
            f"Jobs introuvables ({jobs_path}). Lancez scripts/prepare_dialogue_portrait_batch.py"
        )
    jobs = json.loads(jobs_path.read_text(encoding="utf-8"))
    if character_filter:
        jobs = [j for j in jobs if j.get("character_id") == character_filter]
    return jobs


def _group_by_character(jobs: list[dict]) -> dict[str, list[dict]]:
    grouped: dict[str, list[dict]] = {}
    for job in jobs:
        grouped.setdefault(str(job["character_id"]), []).append(job)
    return grouped


def main() -> int:
    parser = argparse.ArgumentParser(description="Génère les portraits dialogue MVP via ComfyUI")
    parser.add_argument("--character", help="Limiter à un character_id (ex. player_human)")
    parser.add_argument("--dry-run", action="store_true", help="Afficher les jobs sans générer")
    parser.add_argument(
        "--workflow",
        type=Path,
        default=WORKFLOW,
        help="Workflow ComfyUI JSON",
    )
    args = parser.parse_args()

    jobs = _load_jobs(args.character)
    if not jobs:
        print("Aucun job à traiter.")
        return 1

    grouped = _group_by_character(jobs)
    print(f"{len(jobs)} image(s) à générer pour {len(grouped)} personnage(s).")

    if args.dry_run:
        for job in jobs:
            print(
                f"  {job['character_id']}/{job['expression']} "
                f"seed={job['seed']} lora={job['lora']}"
            )
        return 0

    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    orchestrator = PROJECT_DIR / "orchestrator.py"
    venv_python = PROJECT_DIR / ".venv/bin/python"
    python = str(venv_python if venv_python.exists() else Path(sys.executable))

    for char_id, char_jobs in grouped.items():
        char_out = OUTPUT_ROOT / char_id
        char_out.mkdir(parents=True, exist_ok=True)
        summary = json.loads((BATCH_ROOT / char_id / "_summary.json").read_text(encoding="utf-8"))
        lora = str(summary.get("lora", "mmorpg_insp_lora.safetensors"))

        for job in char_jobs:
            expression = str(job["expression"])
            prompt = Path(job["prompt_file"]).read_text(encoding="utf-8").strip()
            neg_path = job.get("negative_file")
            if neg_path and Path(neg_path).is_file():
                negative = Path(neg_path).read_text(encoding="utf-8").strip()
            else:
                fallback_neg = BATCH_ROOT / char_id / "_negative.prompt.txt"
                negative = (
                    fallback_neg.read_text(encoding="utf-8").strip()
                    if fallback_neg.is_file()
                    else ""
                )
            seed = int(job.get("seed", summary.get("seed", 88000)))
            staging = char_out / "_staging"
            staging.mkdir(parents=True, exist_ok=True)
            for old in staging.glob("*.png"):
                old.unlink()

            cmd = [
                python,
                str(orchestrator),
                "generate",
                "--workflow",
                str(args.workflow),
                "--prompt",
                prompt,
                "--negative-prompt",
                negative,
                "--lora",
                lora,
                "--seed",
                str(seed),
                "--output-dir",
                str(staging),
            ]
            print(f"=== {char_id} / {expression} ===")
            result = subprocess.run(cmd, cwd=PROJECT_DIR, check=False)
            if result.returncode != 0:
                print(f"Échec génération {char_id}/{expression}", file=sys.stderr)
                return result.returncode

            pngs = sorted(staging.glob("*.png"), key=lambda p: p.stat().st_mtime)
            if not pngs:
                print(f"Aucun PNG pour {char_id}/{expression}", file=sys.stderr)
                return 1
            latest = pngs[-1]
            dest = char_out / f"{expression}.png"
            shutil.copy2(latest, dest)
            print(f"→ {dest}")

    print(f"Lot terminé : {OUTPUT_ROOT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
