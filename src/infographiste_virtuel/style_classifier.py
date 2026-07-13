"""Classification des images d'inspiration par profil de style (LoRA)."""

from __future__ import annotations

import json
import re
import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from .dataset import IMAGE_EXTENSIONS, scan_dataset


def load_art_styles(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or "styles" not in data:
        raise ValueError(f"art_styles invalide: {path}")
    return data


def _norm_token(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")


def _caption_for_image(image_path: Path) -> str:
    caption_path = image_path.with_suffix(".txt")
    if not caption_path.is_file():
        return ""
    try:
        return caption_path.read_text(encoding="utf-8", errors="ignore").lower()
    except OSError:
        return ""


def _score_style(
    *,
    rel_parts: list[str],
    filename: str,
    caption: str,
    style_id: str,
    style_cfg: dict[str, Any],
) -> tuple[float, list[str]]:
    reasons: list[str] = []
    score = 0.0

    if len(rel_parts) >= 2 and rel_parts[0] == "styles" and rel_parts[1] == style_id:
        return 1.0, [f"dossier styles/{style_id}"]

    folder_hints = [_norm_token(x) for x in style_cfg.get("folder_hints") or []]
    keywords = [_norm_token(x) for x in style_cfg.get("keywords") or []]
    path_blob = _norm_token("/".join(rel_parts + [filename]))
    caption_norm = _norm_token(caption)

    for hint in folder_hints:
        if not hint:
            continue
        if any(hint in _norm_token(part) for part in rel_parts):
            score = max(score, 0.88)
            reasons.append(f"dossier~{hint}")
        elif hint in path_blob:
            score = max(score, 0.82)
            reasons.append(f"chemin~{hint}")

    for kw in keywords:
        if not kw:
            continue
        if kw in path_blob:
            score = max(score, 0.72)
            reasons.append(f"fichier~{kw}")
        if kw in caption_norm:
            score = max(score, 0.66)
            reasons.append(f"caption~{kw}")

    if style_id in path_blob:
        score = max(score, 0.75)
        reasons.append(f"id_style~{style_id}")

    return score, reasons


def classify_image(
    *,
    relative_path: Path,
    image_path: Path,
    styles_doc: dict[str, Any],
) -> tuple[str, float, list[str]]:
    styles = styles_doc.get("styles") or {}
    default_style = str(styles_doc.get("default_style") or "unclassified")
    rel_parts = [p for p in relative_path.parts[:-1]]
    filename = relative_path.name
    caption = _caption_for_image(image_path)

    best_id = default_style
    best_score = 0.0
    best_reasons: list[str] = []

    for style_id, style_cfg in styles.items():
        if not isinstance(style_cfg, dict):
            continue
        score, reasons = _score_style(
            rel_parts=rel_parts,
            filename=filename,
            caption=caption,
            style_id=style_id,
            style_cfg=style_cfg,
        )
        if score > best_score:
            best_score = score
            best_id = style_id
            best_reasons = reasons

    if best_score <= 0.0:
        return default_style, 0.0, ["aucune règle"]
    return best_id, round(best_score, 3), best_reasons


@dataclass
class ClassifiedImage:
    path: Path
    relative_path: Path
    style_id: str
    confidence: float
    reasons: list[str] = field(default_factory=list)
    has_caption: bool = False


@dataclass
class StyleScanReport:
    root: Path
    styles_path: Path
    images: list[ClassifiedImage]

    @property
    def count(self) -> int:
        return len(self.images)

    def buckets(self) -> dict[str, list[ClassifiedImage]]:
        out: dict[str, list[ClassifiedImage]] = {}
        for img in self.images:
            out.setdefault(img.style_id, []).append(img)
        return out

    def to_dict(self) -> dict[str, Any]:
        buckets = self.buckets()
        return {
            "root": str(self.root),
            "styles_path": str(self.styles_path),
            "count": self.count,
            "by_style": {
                style_id: {
                    "count": len(items),
                    "avg_confidence": round(
                        sum(i.confidence for i in items) / max(len(items), 1),
                        3,
                    ),
                    "sample": [str(i.relative_path) for i in items[:5]],
                }
                for style_id, items in sorted(buckets.items(), key=lambda kv: (-len(kv[1]), kv[0]))
            },
            "unclassified": len(buckets.get("unclassified", [])),
            "ready_for_lora": [
                style_id
                for style_id, items in buckets.items()
                if style_id != "unclassified" and len(items) >= 20
            ],
        }


def scan_and_classify(dataset_dir: Path, styles_path: Path) -> StyleScanReport:
    styles_doc = load_art_styles(styles_path)
    base = scan_dataset(dataset_dir)
    classified: list[ClassifiedImage] = []
    for item in base.images:
        style_id, confidence, reasons = classify_image(
            relative_path=item.relative_path,
            image_path=item.path,
            styles_doc=styles_doc,
        )
        classified.append(
            ClassifiedImage(
                path=item.path,
                relative_path=item.relative_path,
                style_id=style_id,
                confidence=confidence,
                reasons=reasons,
                has_caption=item.has_caption,
            )
        )
    return StyleScanReport(root=dataset_dir, styles_path=styles_path, images=classified)


def sort_into_style_dirs(
    report: StyleScanReport,
    *,
    output_root: Path,
    mode: str = "symlink",
    min_confidence: float = 0.65,
) -> dict[str, int]:
    """Range les images classées dans output_root/styles/{style_id}/."""
    counts: dict[str, int] = {}
    styles_root = output_root / "styles"
    styles_root.mkdir(parents=True, exist_ok=True)

    for img in report.images:
        if img.style_id == "unclassified" or img.confidence < min_confidence:
            dest_dir = styles_root / "unclassified"
        else:
            dest_dir = styles_root / img.style_id
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / img.path.name
        if dest.exists() or dest.is_symlink():
            continue
        if mode == "copy":
            shutil.copy2(img.path, dest)
        elif mode == "move":
            shutil.move(img.path, dest)
        else:
            dest.symlink_to(img.path.resolve())
        counts[dest_dir.name] = counts.get(dest_dir.name, 0) + 1
    return counts


def prepare_style_kohya_datasets(
    report: StyleScanReport,
    output_dir: Path,
    *,
    min_images: int = 15,
    min_confidence: float = 0.65,
) -> dict[str, Any]:
    """Prépare un dossier Kohya par style (hors unclassified)."""
    from .kohya_dataset import prepare_kohya_dataset

    styles_doc = load_art_styles(report.styles_path)
    styles_cfg = styles_doc.get("styles") or {}
    prepared: dict[str, Any] = {}

    for style_id, items in report.buckets().items():
        if style_id == "unclassified":
            continue
        selected = [i for i in items if i.confidence >= min_confidence]
        if len(selected) < min_images:
            prepared[style_id] = {
                "ok": False,
                "count": len(selected),
                "reason": f"moins de {min_images} images (conf >= {min_confidence})",
            }
            continue

        style_cfg = styles_cfg.get(style_id) or {}
        lora_cfg = style_cfg.get("lora") or {}
        trigger = str(lora_cfg.get("trigger_word") or style_id)
        repeats = int(lora_cfg.get("repeats") or 10)
        default_caption = str(lora_cfg.get("default_caption") or f"{trigger}, MMORPG concept art")

        staging = output_dir / "_staging" / style_id
        staging.mkdir(parents=True, exist_ok=True)
        for old in staging.glob("*"):
            if old.is_file() or old.is_symlink():
                old.unlink()

        for item in selected:
            dest = staging / item.path.name
            if not dest.exists():
                dest.symlink_to(item.path.resolve())
            cap = item.path.with_suffix(".txt")
            if cap.is_file():
                shutil.copy2(cap, dest.with_suffix(".txt"))
            else:
                dest.with_suffix(".txt").write_text(default_caption, encoding="utf-8")

        kohya_report = prepare_kohya_dataset(
            staging,
            output_dir,
            repeats=repeats,
            trigger_word=trigger,
            default_caption=default_caption,
            use_symlinks=True,
        )
        prepared[style_id] = {
            "ok": True,
            "count": len(selected),
            "trigger_word": trigger,
            "repeats": repeats,
            "kohya_folder": f"{kohya_report.repeats}_{kohya_report.trigger_word}",
            "output_lora": lora_cfg.get("output_name"),
        }

    return prepared
