"""Préparation du dataset au format Kohya (sd-scripts)."""

from __future__ import annotations

import shutil
from dataclasses import dataclass
from pathlib import Path

from .dataset import IMAGE_EXTENSIONS, scan_dataset


@dataclass
class KohyaPrepReport:
    output_dir: Path
    images_linked: int
    captions_created: int
    repeats: int
    trigger_word: str


def prepare_kohya_dataset(
    source_dir: Path,
    output_dir: Path,
    *,
    repeats: int = 10,
    trigger_word: str = "mmorpg_insp",
    default_caption: str | None = None,
    use_symlinks: bool = True,
    max_images: int | None = None,
) -> KohyaPrepReport:
    """Structure Kohya : output_dir/{repeats}_{name}/image.jpg + image.txt"""
    report = scan_dataset(source_dir)
    if report.count == 0:
        raise ValueError(f"Aucune image dans {source_dir}")

    folder_name = f"{repeats}_{trigger_word}"
    train_dir = output_dir / folder_name
    if train_dir.exists():
        shutil.rmtree(train_dir)
    train_dir.mkdir(parents=True, exist_ok=True)

    caption_text = default_caption or (
        f"{trigger_word}, fantasy MMORPG concept art, environment, landscape, detailed"
    )

    images = report.images[:max_images] if max_images else report.images
    captions_created = 0

    for item in images:
        dest_img = train_dir / item.path.name
        if use_symlinks:
            dest_img.symlink_to(item.path.resolve())
        else:
            try:
                shutil.copy2(item.path, dest_img)
            except (PermissionError, OSError):
                # drvfs (B:, NAS) : copie sans métadonnées
                shutil.copyfile(item.path, dest_img)

        caption_path = dest_img.with_suffix(".txt")
        if item.has_caption:
            shutil.copy2(item.path.with_suffix(".txt"), caption_path)
        else:
            caption_path.write_text(caption_text, encoding="utf-8")
            captions_created += 1

    return KohyaPrepReport(
        output_dir=output_dir,
        images_linked=len(images),
        captions_created=captions_created,
        repeats=repeats,
        trigger_word=trigger_word,
    )


def print_kohya_prep_report(report: KohyaPrepReport) -> None:
    folder = f"{report.repeats}_{report.trigger_word}"
    print(f"Dataset Kohya prêt : {report.output_dir / folder}")
    print(f"  Images : {report.images_linked}")
    print(f"  Captions générées : {report.captions_created}")
    print(f"  Repeats : {report.repeats}")
    print(f"  Trigger word : {report.trigger_word}")
