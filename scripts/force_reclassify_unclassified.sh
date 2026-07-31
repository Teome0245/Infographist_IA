#!/usr/bin/env bash
# Passe forcée : purge cache vision des unclassified + re-classify Ollama.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
set -a
# shellcheck disable=SC1091
source .env
set +a
export PYTHONPATH=src PYTHONUNBUFFERED=1 INFOGRAPHISTE_VISION_QUEUE=1
export INFOGRAPHISTE_VISION_FORCE_RECLASSIFY=1
export INFOGRAPHISTE_VISION_SKIP_CACHED_STUCK=0
export INFOGRAPHISTE_ELEMENT_REPORT=0

LOG_DIR=/tmp/infographiste_logs
mkdir -p "$LOG_DIR"
STAMP=$(date +%Y%m%d_%H%M%S)
LOG="$LOG_DIR/force_reclassify_${STAMP}.log"
echo "$LOG" >"$LOG_DIR/current_log.txt"
exec >>"$LOG" 2>&1

echo "FORCE_START $(date -Is)"
N0=$(ls -1 dataset/styles_sorted/styles/unclassified 2>/dev/null | wc -l)
echo "unclassified_start=$N0"

# NAS requis pour lire les symlinks
if [ -x scripts/mount_nas_dataset.sh ]; then
  bash scripts/mount_nas_dataset.sh 2>/dev/null || echo "WARN: mount NAS échoué"
fi

echo "Purge caches v5 pour images unclassified…"
python3 - <<'PY'
import hashlib, json
from pathlib import Path
root = Path("dataset/styles_sorted")
uncl = root / "styles" / "unclassified"
cache = root / ".cache_vision"
ext = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
purged = 0
for p in uncl.iterdir():
    if p.suffix.lower() not in ext:
        continue
    try:
        h = hashlib.sha1()
        with p.open("rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
        digest = h.hexdigest()
    except OSError:
        digest = p.name
    for cp in cache.glob(f"v5_{digest}.json"):
        cp.unlink(missing_ok=True)
        purged += 1
print(f"purged={purged}")
PY

# Notification démarrage
{
  echo "🔁 Passe forcée vision — ${N0} unclassified"
  echo "• purge cache + re-classify llava-phi3"
  echo "• log: $LOG"
} | bash scripts/send_element_via_140.sh 2>/dev/null || true

LIMIT="${INFOGRAPHISTE_FORCE_BATCH:-15}"
ROUNDS="${INFOGRAPHISTE_FORCE_ROUNDS:-20}"
for i in $(seq 1 "$ROUNDS"); do
  N=$(ls -1 dataset/styles_sorted/styles/unclassified 2>/dev/null | wc -l)
  echo "FORCE_ROUND $i unclassified=$N $(date -Is)"
  if [ "$N" -lt 5 ]; then
    echo "backlog quasi vide"
    break
  fi
  OUT=$(python3 -u orchestrator.py vision-classify --limit "$LIMIT" --json 2>&1) || true
  echo "$OUT"
  MOVED=$(echo "$OUT" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("moved_out",0))' 2>/dev/null || echo 0)
  SCANNED=$(echo "$OUT" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("scanned",0))' 2>/dev/null || echo 0)
  echo "FORCE_ROUND_DONE $i scanned=$SCANNED moved=$MOVED $(date -Is)"
  if [ "${SCANNED:-0}" -eq 0 ]; then
    echo "plus d'images traitables — stop"
    break
  fi
done

N1=$(ls -1 dataset/styles_sorted/styles/unclassified 2>/dev/null | wc -l)
echo "PREPARE $(date -Is)"
python3 -u orchestrator.py prepare-styles --from-sorted dataset/styles_sorted --min-images 20 --json || true

{
  echo "🏁 Passe forcée terminée"
  bash scripts/vision_pipeline_status.sh
} | bash scripts/send_element_via_140.sh 2>/dev/null || true

echo "FORCE_DONE $(date -Is) start=$N0 end=$N1"
