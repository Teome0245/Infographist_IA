#!/usr/bin/env bash
# Pipeline vision (file d'attente) → prepare-styles
set -uo pipefail
cd /home/sdesh/projects/Infographiste_IA
set -a
# shellcheck disable=SC1091
source .env
set +a
export PYTHONPATH=src PYTHONUNBUFFERED=1 INFOGRAPHISTE_VISION_QUEUE=1
# CR périodique via report_vision_element_loop.sh (évite 429 Synapse LAN)
export INFOGRAPHISTE_ELEMENT_REPORT="${INFOGRAPHISTE_ELEMENT_REPORT:-0}"

LOG="${1:-/tmp/infographiste_logs/pipeline_$(date +%Y%m%d_%H%M%S).log}"
mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1

echo "START $(date -Is)"
for i in $(seq 1 30); do
  N=$(ls -1 dataset/styles_sorted/styles/unclassified 2>/dev/null | wc -l)
  echo "ROUND $i unclassified=$N $(date -Is)"
  if [ "$N" -lt 40 ]; then
    echo "backlog bas — stop vision"
    break
  fi
  python3 -u orchestrator.py vision-classify --limit 20 --json || true
  echo "ROUND_DONE $i $(date -Is)"
  # CR Element best-effort (ne bloque pas le pipeline)
  if [ "${INFOGRAPHISTE_ELEMENT_REPORT:-1}" != "0" ]; then
    bash scripts/vision_pipeline_status.sh \
      | bash scripts/send_element_via_140.sh \
      >>/tmp/infographiste_logs/element_reports.log 2>&1 || true
  fi
done

echo "PREPARE $(date -Is)"
python3 -u orchestrator.py prepare-styles --from-sorted dataset/styles_sorted --min-images 20 --json || true

echo "BUCKETS"
for d in dataset/styles_sorted/styles/*/; do
  echo "$(basename "$d") $(ls -1 "$d" 2>/dev/null | wc -l)"
done
echo "DONE $(date -Is)"
if [ "${INFOGRAPHISTE_ELEMENT_REPORT:-1}" != "0" ]; then
  {
    echo "🏁 Pipeline Infographiste terminé"
    bash scripts/vision_pipeline_status.sh
  } | bash scripts/send_element_via_140.sh \
    >>/tmp/infographiste_logs/element_reports.log 2>&1 || true
fi
