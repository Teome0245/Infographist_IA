#!/usr/bin/env python3
"""Orchestrateur principal — génération d'assets via ComfyUI (LOCAL / DISTRIBUTED)."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Ajoute src/ au PYTHONPATH pour exécution directe
sys.path.insert(0, str(Path(__file__).resolve().parent / "src"))

from infographiste_virtuel.dataset import print_dataset_report, scan_dataset
from infographiste_virtuel.style_classifier import (
    prepare_style_kohya_datasets,
    scan_and_classify,
    sort_into_style_dirs,
)


def _project_root() -> Path:
    return Path(__file__).resolve().parent


def _default_dataset_dir() -> Path:
    return _project_root() / "dataset" / "inspiration_mmorpg"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Infographiste virtuel — orchestration ComfyUI (LOCAL / DISTRIBUTED)"
    )
    sub = parser.add_subparsers(dest="command", required=True)

    scan_cmd = sub.add_parser("scan", help="Scanner le dossier dataset/")
    scan_cmd.add_argument("--dataset-dir", type=Path, default=None)

    gen_cmd = sub.add_parser("generate", help="Générer un asset via ComfyUI")
    gen_cmd.add_argument("--workflow", type=Path, required=True, help="Workflow JSON (API format)")
    gen_cmd.add_argument("--prompt", type=str, required=True, help="Prompt positif")
    gen_cmd.add_argument("--negative-prompt", type=str, default=None)
    gen_cmd.add_argument("--lora", type=str, default=None, help="Nom du fichier LoRA (.safetensors)")
    gen_cmd.add_argument("--seed", type=int, default=None)
    gen_cmd.add_argument("--output-dir", type=Path, default=None)
    gen_cmd.add_argument("--upload", action="store_true", help="Uploader dataset/LoRA vers S3 (DISTRIBUTED)")

    prep_cmd = sub.add_parser("prepare-dataset", help="Préparer dataset Kohya depuis inspiration NAS")
    prep_cmd.add_argument("--source", type=Path, default=None, help="Dossier images source")
    prep_cmd.add_argument("--output", type=Path, default=None, help="Dossier sortie kohya_train")
    prep_cmd.add_argument("--repeats", type=int, default=10, help="Repeats Kohya (préfixe dossier)")
    prep_cmd.add_argument("--trigger", type=str, default="mmorpg_insp", help="Trigger word / nom dossier")
    prep_cmd.add_argument("--max-images", type=int, default=None, help="Limiter le nombre d'images")
    prep_cmd.add_argument("--copy", action="store_true", help="Copier les images (requis pour Kohya Windows)")

    classify_cmd = sub.add_parser("classify", help="Classifier/trier les images par style LoRA")
    classify_cmd.add_argument("--dataset-dir", type=Path, default=None)
    classify_cmd.add_argument("--styles", type=Path, default=None, help="config/art_styles.json")
    classify_cmd.add_argument("--json", action="store_true", help="Sortie JSON (orchestrateur Pygmalion)")
    classify_cmd.add_argument(
        "--sort-to",
        type=Path,
        default=None,
        help="Ranger dans styles/{id}/ (symlinks par défaut)",
    )
    classify_cmd.add_argument("--sort-mode", choices=("symlink", "copy", "move"), default="symlink")
    classify_cmd.add_argument("--min-confidence", type=float, default=0.65)

    prep_styles_cmd = sub.add_parser(
        "prepare-styles",
        help="Préparer un dataset Kohya par profil de style",
    )
    prep_styles_cmd.add_argument("--dataset-dir", type=Path, default=None)
    prep_styles_cmd.add_argument("--styles", type=Path, default=None)
    prep_styles_cmd.add_argument("--output", type=Path, default=None)
    prep_styles_cmd.add_argument("--min-images", type=int, default=15)
    prep_styles_cmd.add_argument("--json", action="store_true")

    return parser


def cmd_scan(args: argparse.Namespace) -> int:
    from infographiste_virtuel.config import load_config

    cfg = load_config()
    dataset_dir = args.dataset_dir or cfg.dataset_dir
    report = scan_dataset(dataset_dir)
    print_dataset_report(report)
    if report.count == 0:
        print("Attention: aucune image trouvée dans le dataset.")
        return 1
    return 0


def cmd_generate(args: argparse.Namespace) -> int:
    from infographiste_virtuel.config import load_config
    from infographiste_virtuel.comfy_client import ComfyUIClient
    from infographiste_virtuel.storage import StorageManager
    from infographiste_virtuel.workflow_patch import load_workflow, patch_workflow

    cfg = load_config()
    output_dir = args.output_dir or cfg.assets_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    if cfg.infra.mode == "DISTRIBUTED" and args.upload:
        storage = StorageManager(cfg.storage)
        print(f"Upload dataset -> {cfg.storage.s3_bucket}")
        storage.upload_dataset(cfg.dataset_dir)
        if args.lora:
            lora_path = cfg.local_lora_dir / args.lora
            if lora_path.exists():
                uri = storage.upload_lora(lora_path)
                print(f"LoRA uploadé: {uri}")

    workflow = load_workflow(args.workflow)
    patched = patch_workflow(
        workflow,
        prompt_text=args.prompt,
        negative_prompt=args.negative_prompt,
        lora_name=args.lora,
        prompt_nodes=cfg.workflow.prompt_nodes,
        negative_nodes=cfg.workflow.negative_nodes,
        lora_nodes=cfg.workflow.lora_nodes,
        seed=args.seed,
    )

    base_url = cfg.comfy_base_url()
    print(f"Mode: {cfg.infra.mode} | Endpoint: {base_url}")

    client = ComfyUIClient(base_url, cfg.infra)
    images = client.run_workflow(patched, output_dir)

    if not images:
        print("Aucune image retournée par ComfyUI.")
        return 1

    print(f"{len(images)} image(s) sauvegardée(s) dans {output_dir}:")
    for img in images:
        print(f"  - {img.local_path}")
    return 0


def _default_styles_path() -> Path:
    return _project_root() / "config" / "art_styles.json"


def cmd_classify(args: argparse.Namespace) -> int:
    import json as json_mod

    dataset_dir = args.dataset_dir or _default_dataset_dir()
    styles_path = args.styles or _default_styles_path()
    report = scan_and_classify(dataset_dir, styles_path)

    sort_counts: dict[str, int] | None = None
    if args.sort_to:
        sort_counts = sort_into_style_dirs(
            report,
            output_root=args.sort_to,
            mode=args.sort_mode,
            min_confidence=args.min_confidence,
        )

    payload = report.to_dict()
    payload["sort_counts"] = sort_counts
    if args.json:
        print(json_mod.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print(f"Dataset: {report.root}")
        print(f"  Styles: {styles_path}")
        print(f"  Images: {report.count}")
        for style_id, meta in payload["by_style"].items():
            print(f"  - {style_id}: {meta['count']} (conf moy. {meta['avg_confidence']})")
        if sort_counts:
            print(f"  Tri → {args.sort_to}: {sort_counts}")
        if payload.get("ready_for_lora"):
            print(f"  Prêts LoRA (≥20 img): {', '.join(payload['ready_for_lora'])}")

    if report.count == 0:
        return 1
    return 0


def cmd_prepare_styles(args: argparse.Namespace) -> int:
    import json as json_mod

    dataset_dir = args.dataset_dir or _default_dataset_dir()
    styles_path = args.styles or _default_styles_path()
    output = args.output or (_project_root() / "dataset" / "kohya_train_by_style")
    report = scan_and_classify(dataset_dir, styles_path)
    prepared = prepare_style_kohya_datasets(
        report,
        output,
        min_images=args.min_images,
    )
    payload = {"output": str(output), "styles": prepared, "scan": report.to_dict()}
    if args.json:
        print(json_mod.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print(f"Datasets Kohya par style → {output}")
        for style_id, meta in prepared.items():
            if meta.get("ok"):
                print(f"  OK {style_id}: {meta['count']} img → {meta['kohya_folder']}")
            else:
                print(f"  SKIP {style_id}: {meta.get('reason')}")
    return 0 if any(v.get("ok") for v in prepared.values()) else 1


def cmd_prepare_dataset(args: argparse.Namespace) -> int:
    from infographiste_virtuel.config import load_config
    from infographiste_virtuel.kohya_dataset import prepare_kohya_dataset, print_kohya_prep_report

    cfg = load_config()
    source = args.source or cfg.dataset_dir
    output = args.output or (cfg.project_root / "dataset" / "kohya_train")

    report = prepare_kohya_dataset(
        source,
        output,
        repeats=args.repeats,
        trigger_word=args.trigger,
        max_images=args.max_images,
        use_symlinks=not args.copy,
    )
    print_kohya_prep_report(report)
    return 0


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.command == "scan":
        return cmd_scan(args)
    if args.command == "generate":
        return cmd_generate(args)
    if args.command == "prepare-dataset":
        return cmd_prepare_dataset(args)
    if args.command == "classify":
        return cmd_classify(args)
    if args.command == "prepare-styles":
        return cmd_prepare_styles(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
