"""Classification des images d'inspiration par profil de style (LoRA)."""

from __future__ import annotations

import hashlib
import json
import re
import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from .dataset import IMAGE_EXTENSIONS, scan_dataset
from .ollama_vision import OllamaConfig, generate as ollama_generate, ollama_config_from_env


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


def _style_ids(styles_doc: dict[str, Any]) -> list[str]:
    styles = styles_doc.get("styles") or {}
    return [k for k in styles.keys() if isinstance(k, str)]


def _vision_prompt(styles_doc: dict[str, Any]) -> str:
    styles = styles_doc.get("styles") or {}
    lines = [
        "Tu es un classificateur d'images pour un MMO.",
        "Choisis le meilleur style_id parmi la liste, ou 'unclassified' si tu es incertain.",
        "Réponds STRICTEMENT en JSON avec ces champs:",
        '{"style_id": "...", "confidence": 0.0-1.0, "tags": ["..."], "notes": "..."}',
        "",
        "Styles disponibles:",
    ]
    for sid, cfg in styles.items():
        if not isinstance(sid, str) or not isinstance(cfg, dict):
            continue
        label = str(cfg.get("label") or sid)
        hints = cfg.get("keywords") or cfg.get("folder_hints") or []
        hints_s = ", ".join(str(x) for x in (hints[:8] if isinstance(hints, list) else []))
        lines.append(f"- {sid}: {label} (indices: {hints_s})")
    lines.append("")
    lines.append("Règles:")
    lines.append("- Ne renvoie aucun texte hors JSON.")
    lines.append("- Si ce n'est pas un asset MMO (photo perso, etc.), renvoie unclassified.")
    return "\n".join(lines)


def _safe_parse_json(text: str) -> dict[str, Any] | None:
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


def _sha1(path: Path) -> str:
    h = hashlib.sha1()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def vision_classify_image(
    *,
    image_path: Path,
    styles_doc: dict[str, Any],
    cfg: OllamaConfig | None = None,
) -> tuple[str, float, list[str], str]:
    """Classifie une image via Ollama vision.

    Returns: (style_id, confidence, tags, notes)
    """
    cfg = cfg or ollama_config_from_env()
    prompt = _vision_prompt(styles_doc)
    raw = ollama_generate(cfg, prompt=prompt, image_path=str(image_path))
    parsed = _safe_parse_json(raw)
    if not parsed:
        return "unclassified", 0.0, [], "invalid_json"
    style_id = str(parsed.get("style_id") or "unclassified")
    try:
        conf = float(parsed.get("confidence") or 0.0)
    except (TypeError, ValueError):
        conf = 0.0
    tags = parsed.get("tags")
    if not isinstance(tags, list):
        tags = []
    tags_s = [str(t) for t in tags[:12]]
    notes = str(parsed.get("notes") or "")

    valid = set(_style_ids(styles_doc))
    valid.add("unclassified")
    if style_id not in valid:
        style_id = "unclassified"
        conf = 0.0
    if conf < 0.0:
        conf = 0.0
    if conf > 1.0:
        conf = 1.0
    return style_id, round(conf, 3), tags_s, notes[:200]


def vision_classify_unclassified(
    *,
    unclassified_dir: Path,
    styles_path: Path,
    output_root: Path,
    cache_dir: Path | None = None,
    limit: int | None = None,
    min_confidence: float = 0.7,
    ollama_cfg: OllamaConfig | None = None,
    mode: str = "symlink",
) -> dict[str, Any]:
    """Parcourt un dossier d'images (souvent symlinks) et range selon vision.

    Écrit un cache JSON par image (sha1) pour éviter de reclasser.
    """
    styles_doc = load_art_styles(styles_path)
    cache = cache_dir or (output_root / ".cache_vision")
    cache.mkdir(parents=True, exist_ok=True)

    if not unclassified_dir.is_dir():
        raise FileNotFoundError(f"Dossier unclassified introuvable: {unclassified_dir}")

    images = [p for p in sorted(unclassified_dir.iterdir()) if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS]
    if limit is not None:
        images = images[: max(0, int(limit))]

    counts: dict[str, int] = {}
    decisions: list[dict[str, Any]] = []

    for img in images:
        try:
            digest = _sha1(img.resolve() if img.is_symlink() else img)
        except OSError:
            digest = img.name
        cache_path = cache / f"{digest}.json"
        cached = None
        if cache_path.is_file():
            cached = _safe_parse_json(cache_path.read_text(encoding="utf-8", errors="ignore"))

        if cached and isinstance(cached.get("style_id"), str):
            style_id = cached.get("style_id")
            confidence = float(cached.get("confidence") or 0.0)
            tags = cached.get("tags") if isinstance(cached.get("tags"), list) else []
            notes = str(cached.get("notes") or "cache")
        else:
            style_id, confidence, tags, notes = vision_classify_image(
                image_path=img.resolve() if img.is_symlink() else img,
                styles_doc=styles_doc,
                cfg=ollama_cfg,
            )
            cache_path.write_text(
                json.dumps(
                    {
                        "image": str(img),
                        "style_id": style_id,
                        "confidence": confidence,
                        "tags": tags,
                        "notes": notes,
                    },
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )

        final_style = style_id if (style_id != "unclassified" and confidence >= min_confidence) else "unclassified"

        # Range l'image (symlink/copy/move) sous output_root/styles/{style_id}
        tmp_report = StyleScanReport(root=unclassified_dir, styles_path=styles_path, images=[])
        dest_dir = (output_root / "styles" / final_style)
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / img.name
        if not dest.exists() and not dest.is_symlink():
            if mode == "copy":
                shutil.copy2(img, dest)
            elif mode == "move":
                shutil.move(img, dest)
            else:
                dest.symlink_to((img.resolve() if img.is_symlink() else img).resolve())

        counts[final_style] = counts.get(final_style, 0) + 1
        decisions.append(
            {
                "file": img.name,
                "style_id": style_id,
                "confidence": confidence,
                "final_style": final_style,
                "tags": tags[:6],
            }
        )

    return {
        "ok": True,
        "scanned": len(images),
        "min_confidence": min_confidence,
        "counts": counts,
        "sample": decisions[:10],
        "output_root": str(output_root),
        "cache_dir": str(cache),
    }
