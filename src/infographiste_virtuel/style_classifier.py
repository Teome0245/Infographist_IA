"""Classification des images d'inspiration par profil de style (LoRA)."""

from __future__ import annotations

import hashlib
import json
import os
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


def prepare_kohya_from_sorted_buckets(
    sorted_root: Path,
    output_dir: Path,
    styles_path: Path,
    *,
    min_images: int = 15,
) -> dict[str, Any]:
    """Prépare Kohya depuis dataset/styles_sorted/styles/{style_id}/ (post vision)."""
    from .kohya_dataset import prepare_kohya_dataset

    styles_doc = load_art_styles(styles_path)
    styles_cfg = styles_doc.get("styles") or {}
    prepared: dict[str, Any] = {}
    styles_dir = sorted_root / "styles"
    if not styles_dir.is_dir():
        return {"error": f"dossier styles absent: {styles_dir}"}

    for style_dir in sorted(styles_dir.iterdir()):
        if not style_dir.is_dir() or style_dir.name == "unclassified":
            continue
        style_id = style_dir.name
        images = [
            p for p in sorted(style_dir.iterdir())
            if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
        ]
        if len(images) < min_images:
            prepared[style_id] = {
                "ok": False,
                "count": len(images),
                "reason": f"moins de {min_images} images dans {style_dir}",
            }
            continue

        style_cfg = styles_cfg.get(style_id) or {}
        lora_cfg = style_cfg.get("lora") or {}
        trigger = str(lora_cfg.get("trigger_word") or style_id)
        repeats = int(lora_cfg.get("repeats") or 10)
        default_caption = str(lora_cfg.get("default_caption") or f"{trigger}, MMORPG concept art")

        kohya_report = prepare_kohya_dataset(
            style_dir,
            output_dir,
            repeats=repeats,
            trigger_word=trigger,
            default_caption=default_caption,
            use_symlinks=True,
        )
        prepared[style_id] = {
            "ok": True,
            "count": len(images),
            "source": str(style_dir),
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
    rules = styles_doc.get("vision_rules") if isinstance(styles_doc.get("vision_rules"), dict) else {}
    compact = os.environ.get("OLLAMA_VISION_COMPACT_PROMPT", "1").strip().lower() not in (
        "0",
        "false",
        "no",
    )
    if compact:
        # Ordre: styles fréquents d'abord (évite l'écho « premier id » des petits VLM)
        preferred = [
            "character_portrait",
            "mmorpg_general",
            "prime_sprite_2d",
            "map_topdown",
            "fantasy_landscape",
            "scifi_city",
            "vehicles_ships",
            "creatures_alien",
            "props_gear",
            "imperial_tech",
            "cantina_interior",
            "tatooine_desert",
            "unclassified",
        ]
        all_ids = [sid for sid in styles.keys() if isinstance(sid, str)]
        ids = [s for s in preferred if s in all_ids] + [s for s in all_ids if s not in preferred]
        ids_s = ", ".join(ids)
        return "\n".join(
            [
                "Classify this game/art image into ONE style_id from this list:",
                ids_s,
                'Reply with ONLY one JSON object (no markdown):',
                '{"style_id":"<id>","confidence":0.0,"tags":[],"notes":""}',
                "Rules:",
                "- style_id MUST be exactly one id from the list (never '...' or empty).",
                "- Prefer a close theme over unclassified.",
                "- character_portrait = people/characters/cosplay.",
                "- prime_sprite_2d = top-down unit/sprite token.",
                "- map_topdown = top-down map/terrain (not a character).",
                "- mmorpg_general = game art that fits no precise theme.",
                "- unclassified = only if unrelated IRL/OS screenshot/unreadable.",
                "- confidence 0.8+ sure, 0.55-0.79 likely, 0.45-0.54 best guess.",
                "- Put a short visual note in notes (5-12 words).",
            ]
        )

    lines = [
        "Tu es un classificateur d'images pour un MMORPG (Star Wars Galaxies / fantasy sci-fi).",
        "Objectif: ranger CHAQUE image dans un thème précis pour entraîner un LoRA dédié.",
        "Choisis TOUJOURS le style_id le plus proche dans la liste.",
        "Réponds STRICTEMENT en JSON:",
        '{"style_id": "...", "confidence": 0.0-1.0, "tags": ["..."], "notes": "..."}',
        "",
        "Styles disponibles:",
    ]
    for sid, cfg in styles.items():
        if not isinstance(sid, str) or not isinstance(cfg, dict):
            continue
        label = str(cfg.get("label") or sid)
        hints = cfg.get("keywords") or cfg.get("folder_hints") or []
        hints_s = ", ".join(str(x) for x in (hints[:10] if isinstance(hints, list) else []))
        lines.append(f"- {sid}: {label} (indices: {hints_s})")
    lines.append("")
    lines.append("Règles STRICTES:")
    lines.append("- Ne renvoie aucun texte hors JSON.")
    lines.append("- Préfère un thème proche plutôt que unclassified.")
    lines.append(
        "- Utilise mmorpg_general seulement si c'est clairement un asset/concept de jeu "
        "mais aucun thème précis ne convient."
    )
    lines.append(
        "- character_portrait: personnages, cosplay, portraits (même photo costumée)."
    )
    lines.append(
        "- prime_sprite_2d: sprite / token / personnage vu du dessus (unité jouable), "
        "pas une carte de terrain."
    )
    lines.append(
        "- map_topdown: carte de jeu 2D vue du dessus — world map, tilemap, terrain, "
        "ville en plan, stratégie, minimap. PRIORITÉ si l'image est une carte/terrain "
        "et non un personnage isolé."
    )
    unclassified_only = str(
        rules.get("unclassified_only_if")
        or "photo IRL hors sujet jeu, capture OS, image illisible"
    )
    lines.append(f"- unclassified UNIQUEMENT si: {unclassified_only}.")
    lines.append("- confidence: 0.8+ sûr, 0.55-0.79 probable, 0.45-0.54 meilleur guess.")
    return "\n".join(lines)


def _resolve_final_style(
    *,
    style_id: str,
    confidence: float,
    styles_doc: dict[str, Any],
    min_confidence: float,
) -> str:
    """Décide le bucket final — soft assign pour sortir d'unclassified."""
    valid = set(_style_ids(styles_doc))
    rules = styles_doc.get("vision_rules") if isinstance(styles_doc.get("vision_rules"), dict) else {}
    soft = float(rules.get("soft_confidence") or 0.45)

    if style_id not in valid:
        return "unclassified"
    if style_id == "unclassified":
        return "unclassified"
    if confidence >= min_confidence:
        return style_id
    # Soft: thème valide mais confiance moyenne → ranger quand même (LoRA thématique)
    if confidence >= soft and bool(rules.get("prefer_assignment", True)):
        return style_id
    return "unclassified"


def _cache_version(styles_doc: dict[str, Any]) -> str:
    return f"v{int(styles_doc.get('version') or 1)}"


def _safe_parse_json(text: str) -> dict[str, Any] | None:
    raw = (text or "").strip()
    if not raw:
        return None
    if raw.startswith("```"):
        raw = raw.strip("`")
        if raw.lower().startswith("json"):
            raw = raw[4:].strip()
    start = raw.find("{")
    if start < 0:
        return None

    # Essais: objet complet, puis troncature progressive (petits modèles qui bouclent)
    candidates: list[str] = []
    end = raw.rfind("}")
    if end > start:
        candidates.append(raw[start : end + 1])
    # Première fermeture plausible après style_id
    depth = 0
    for i, ch in enumerate(raw[start:], start=start):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                candidates.insert(0, raw[start : i + 1])
                break

    for cand in candidates:
        try:
            data = json.loads(cand)
        except json.JSONDecodeError:
            continue
        if not isinstance(data, dict):
            continue
        if "style_id" not in data and isinstance(data.get("styleId"), str):
            data["style_id"] = data["styleId"]
        if "style_id" not in data and isinstance(data.get("style"), str):
            data["style_id"] = data["style"]
        sid = data.get("style_id")
        if isinstance(sid, str):
            sid = sid.strip().strip('"').strip("'")
            if sid in ("", "...", "<id>", "style_id", "null", "none"):
                continue
            data["style_id"] = sid
            return data

    # Fallback regex si JSON cassé (moondream qui répète des clés)
    m = re.search(r'"style_id"\s*:\s*"([^"]+)"', raw)
    if not m:
        return None
    sid = m.group(1).strip()
    if sid in ("", "...", "<id>", "style_id"):
        return None
    conf = 0.0
    cm = re.search(r'"confidence"\s*:\s*([0-9]*\.?[0-9]+)', raw)
    if cm:
        try:
            conf = float(cm.group(1))
        except ValueError:
            conf = 0.0
    # moondream: confidence 0.0 + 1er id de liste = echo, PAS une vraie classif
    if conf <= 0.0:
        return {
            "style_id": "unclassified",
            "confidence": 0.0,
            "tags": [],
            "notes": "re_fallback_zero_conf",
        }
    return {"style_id": sid, "confidence": conf, "tags": [], "notes": "re_fallback"}


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


def _vision_lock_path() -> Path:
    override = os.environ.get("INFOGRAPHISTE_VISION_LOCK", "").strip()
    if override:
        return Path(override)
    return Path("/tmp/infographiste_vision_classify.lock")


def _vision_queue_dir() -> Path:
    override = os.environ.get("INFOGRAPHISTE_VISION_QUEUE_DIR", "").strip()
    if override:
        return Path(override)
    return Path("/tmp/infographiste_vision_queue")


def _vision_queue_timeout_s() -> float:
    try:
        return float(os.environ.get("INFOGRAPHISTE_VISION_QUEUE_TIMEOUT_S", "7200"))
    except ValueError:
        return 7200.0


def _vision_queue_enabled() -> bool:
    raw = os.environ.get("INFOGRAPHISTE_VISION_QUEUE", "1").strip().lower()
    return raw not in ("0", "false", "no", "off")


def _acquire_vision_lock(
    lock_fh: Any,
    *,
    wait: bool,
    timeout_s: float,
) -> tuple[bool, float, int, str]:
    """Prend le verrou exclusif.

    Returns: (ok, waited_s, queue_position, detail)
    - wait=True : file d'attente (poll) jusqu'à timeout
    - wait=False : refus immédiat si occupé
    """
    import fcntl
    import time

    queue_dir = _vision_queue_dir()
    queue_dir.mkdir(parents=True, exist_ok=True)
    ticket = queue_dir / f"{os.getpid()}.waiting"
    started = time.monotonic()
    position = 1

    try:
        fcntl.flock(lock_fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        return True, 0.0, 0, "acquired"
    except BlockingIOError:
        if not wait:
            return False, 0.0, 0, "busy_no_wait"

    # En file d'attente
    try:
        ticket.write_text(
            json.dumps({"pid": os.getpid(), "since": time.time()}, ensure_ascii=False),
            encoding="utf-8",
        )
    except OSError:
        pass

    try:
        while True:
            waited = time.monotonic() - started
            waiters = sorted(queue_dir.glob("*.waiting"))
            # Position approx. : ordre par mtime puis nom
            names = [p.name for p in waiters]
            try:
                position = names.index(ticket.name) + 1
            except ValueError:
                position = len(names) + 1

            if waited >= timeout_s:
                return False, waited, position, f"queue_timeout_{int(timeout_s)}s"

            try:
                fcntl.flock(lock_fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                waited = time.monotonic() - started
                return True, waited, position, "acquired_after_wait"
            except BlockingIOError:
                time.sleep(1.0)
    finally:
        try:
            if ticket.exists():
                ticket.unlink()
        except OSError:
            pass


def vision_classify_unclassified(
    *,
    unclassified_dir: Path,
    styles_path: Path,
    output_root: Path,
    cache_dir: Path | None = None,
    limit: int | None = None,
    min_confidence: float = 0.55,
    ollama_cfg: OllamaConfig | None = None,
    mode: str = "symlink",
    wait_queue: bool | None = None,
    queue_timeout_s: float | None = None,
) -> dict[str, Any]:
    """Parcourt unclassified et range selon vision.

    - Cache JSON par sha1 (+version taxonomie) pour éviter de reclassifier à l'identique.
    - Après placement réussi hors unclassified: retire l'entrée de unclassified
      (sinon le compteur ne baisse jamais en mode symlink).
    - File d'attente : 1 seul job GPU à la fois ; les suivants attendent (flock).
    """
    import fcntl

    wait = _vision_queue_enabled() if wait_queue is None else bool(wait_queue)
    timeout_s = _vision_queue_timeout_s() if queue_timeout_s is None else float(queue_timeout_s)

    lock_path = _vision_lock_path()
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    lock_fh = open(lock_path, "a+", encoding="utf-8")
    ok, waited_s, position, detail = _acquire_vision_lock(
        lock_fh, wait=wait, timeout_s=timeout_s
    )
    if not ok:
        lock_fh.close()
        if detail == "busy_no_wait":
            err = (
                "Un autre vision-classify est déjà en cours "
                f"(lock {lock_path}). Relancer avec file d'attente "
                "(défaut) ou attendre la fin du job."
            )
        else:
            err = (
                f"Timeout file d'attente vision ({int(timeout_s)}s) "
                f"après ~{int(waited_s)}s (position ~{position}). "
                f"Lock: {lock_path}"
            )
        return {
            "ok": False,
            "scanned": 0,
            "moved_out": 0,
            "min_confidence": min_confidence,
            "counts": {},
            "sample": [],
            "queued": True,
            "queue_waited_s": round(waited_s, 1),
            "queue_position": position,
            "error": err,
            "output_root": str(output_root),
        }

    try:
        report = _vision_classify_unclassified_locked(
            unclassified_dir=unclassified_dir,
            styles_path=styles_path,
            output_root=output_root,
            cache_dir=cache_dir,
            limit=limit,
            min_confidence=min_confidence,
            ollama_cfg=ollama_cfg,
            mode=mode,
        )
        if isinstance(report, dict):
            report["queue_waited_s"] = round(waited_s, 1)
            report["queue_position"] = position
            report["queue_detail"] = detail
        return report
    finally:
        try:
            fcntl.flock(lock_fh.fileno(), fcntl.LOCK_UN)
        except OSError:
            pass
        lock_fh.close()


def _vision_classify_unclassified_locked(
    *,
    unclassified_dir: Path,
    styles_path: Path,
    output_root: Path,
    cache_dir: Path | None = None,
    limit: int | None = None,
    min_confidence: float = 0.55,
    ollama_cfg: OllamaConfig | None = None,
    mode: str = "symlink",
) -> dict[str, Any]:
    styles_doc = load_art_styles(styles_path)
    cache_ver = _cache_version(styles_doc)
    cache = cache_dir or (output_root / ".cache_vision")
    cache.mkdir(parents=True, exist_ok=True)

    if not unclassified_dir.is_dir():
        raise FileNotFoundError(f"Dossier unclassified introuvable: {unclassified_dir}")

    # IMPORTANT: ne pas utiliser Path.is_file() (suit le symlink → stat NAS 9p = hang).
    # On liste via lstat ; la lisibilité de la cible est testée image par image.
    import stat as _stat

    entries = sorted(unclassified_dir.iterdir())
    images: list[Path] = []
    dangling: list[Path] = []
    skip_stuck = os.environ.get("INFOGRAPHISTE_VISION_SKIP_CACHED_STUCK", "1").strip().lower() not in (
        "0",
        "false",
        "no",
    )
    force_reclassify = os.environ.get("INFOGRAPHISTE_VISION_FORCE_RECLASSIFY", "0").strip().lower() in (
        "1",
        "true",
        "yes",
    )
    max_n = None if limit is None else max(0, int(limit))

    for p in entries:
        if max_n is not None and len(images) >= max_n:
            break
        if p.suffix.lower() not in IMAGE_EXTENSIONS:
            continue
        try:
            st = p.lstat()
        except OSError:
            continue
        if not (_stat.S_ISLNK(st.st_mode) or _stat.S_ISREG(st.st_mode)):
            continue
        if skip_stuck and not force_reclassify:
            try:
                digest = _sha1(p)
            except OSError:
                digest = p.name
            cache_path = cache / f"{cache_ver}_{digest}.json"
            if cache_path.is_file():
                cached = _safe_parse_json(cache_path.read_text(encoding="utf-8", errors="ignore"))
                if cached and isinstance(cached.get("style_id"), str):
                    try:
                        conf = float(cached.get("confidence") or 0.0)
                    except (TypeError, ValueError):
                        conf = 0.0
                    final = _resolve_final_style(
                        style_id=str(cached.get("style_id") or "unclassified"),
                        confidence=conf,
                        styles_doc=styles_doc,
                        min_confidence=min_confidence,
                    )
                    if final == "unclassified":
                        continue
        images.append(p)

    # Spot-check dangling seulement sur le lot (os.stat suit le lien ; lot limité)
    for p in images:
        if not p.is_symlink():
            continue
        try:
            os.stat(p)
        except OSError:
            dangling.append(p)
    if dangling:
        dead = {d.name for d in dangling}
        images = [p for p in images if p.name not in dead]

    counts: dict[str, int] = {}
    decisions: list[dict[str, Any]] = []
    moved_out = 0

    if not images and dangling:
        return {
            "ok": False,
            "scanned": 0,
            "moved_out": 0,
            "min_confidence": min_confidence,
            "taxonomy_version": cache_ver,
            "counts": {},
            "sample": [],
            "dangling_symlinks": len(dangling),
            "error": (
                f"{len(dangling)} liens cassés dans unclassified "
                "(cible NAS absente — remonter avec scripts/mount_nas_dataset.sh)"
            ),
            "output_root": str(output_root),
            "cache_dir": str(cache),
        }

    def _symlink_target(path: Path) -> Path:
        """Cible du symlink sans Path.resolve() (évite hangs 9p)."""
        if not path.is_symlink():
            return path
        raw = os.readlink(path)
        tgt = Path(raw)
        return tgt if tgt.is_absolute() else (path.parent / tgt)

    for img in images:
        try:
            digest = _sha1(img)  # open() suit le symlink, sans resolve()
        except OSError:
            digest = img.name
        cache_path = cache / f"{cache_ver}_{digest}.json"
        cached = None
        if not force_reclassify and cache_path.is_file():
            cached = _safe_parse_json(cache_path.read_text(encoding="utf-8", errors="ignore"))

        if not force_reclassify and cached and isinstance(cached.get("style_id"), str):
            style_id = str(cached.get("style_id"))
            confidence = float(cached.get("confidence") or 0.0)
            tags = cached.get("tags") if isinstance(cached.get("tags"), list) else []
            notes = str(cached.get("notes") or "cache")
        else:
            try:
                style_id, confidence, tags, notes = vision_classify_image(
                    image_path=img,
                    styles_doc=styles_doc,
                    cfg=ollama_cfg,
                )
            except Exception as e:  # noqa: BLE001
                style_id, confidence, tags, notes = (
                    "unclassified",
                    0.0,
                    [],
                    f"error:{type(e).__name__}",
                )
            cache_path.write_text(
                json.dumps(
                    {
                        "image": str(img),
                        "style_id": style_id,
                        "confidence": confidence,
                        "tags": tags,
                        "notes": notes,
                        "taxonomy_version": cache_ver,
                    },
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )

        final_style = _resolve_final_style(
            style_id=style_id,
            confidence=confidence,
            styles_doc=styles_doc,
            min_confidence=min_confidence,
        )

        dest_dir = output_root / "styles" / final_style
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / img.name
        if final_style != "unclassified":
            if not dest.exists() and not dest.is_symlink():
                if mode == "copy":
                    shutil.copy2(img, dest)
                elif mode == "move":
                    shutil.move(str(img), str(dest))
                else:
                    dest.symlink_to(_symlink_target(img))
            # Retire de unclassified (unlink le lien local, pas la cible NAS)
            try:
                img.unlink()
                moved_out += 1
            except OSError:
                pass

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
        "moved_out": moved_out,
        "min_confidence": min_confidence,
        "taxonomy_version": cache_ver,
        "counts": counts,
        "sample": decisions[:10],
        "output_root": str(output_root),
        "cache_dir": str(cache),
    }
