#!/usr/bin/env bash
# Reprise après reboot WSL (.10) — vision + CR Element si backlog.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="/tmp/infographiste_logs"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d_%H%M%S)"
RESUME_LOG="$LOG_DIR/resume_${STAMP}.log"
exec >>"$RESUME_LOG" 2>&1

echo "RESUME_START $(date -Is)"

# NAS (symlinks unclassified → images réelles)
if [ -x "$ROOT/scripts/mount_nas_dataset.sh" ]; then
  bash "$ROOT/scripts/mount_nas_dataset.sh" 2>/dev/null || echo "WARN: mount NAS échoué"
fi

UNCL=0
[ -d "$ROOT/dataset/styles_sorted/styles/unclassified" ] && \
  UNCL=$(ls -1 "$ROOT/dataset/styles_sorted/styles/unclassified" 2>/dev/null | wc -l)

THRESHOLD="${INFOGRAPHISTE_RESUME_MIN_UNCLASSIFIED:-40}"
RUNNING=0
pgrep -f 'scripts/run_vision_prepare_pipeline\.sh' >/dev/null 2>&1 && RUNNING=1
pgrep -f 'orchestrator\.py vision-classify' >/dev/null 2>&1 && RUNNING=1

if [ "$RUNNING" -eq 1 ]; then
  echo "SKIP pipeline déjà actif unclassified=$UNCL"
elif [ "$UNCL" -ge "$THRESHOLD" ]; then
  LOG="$LOG_DIR/pipeline_${STAMP}.log"
  echo "$LOG" >"$LOG_DIR/current_log.txt"
  cd "$ROOT"
  nohup bash scripts/run_vision_prepare_pipeline.sh "$LOG" \
    >"$LOG_DIR/nohup_pipeline.out" 2>&1 &
  echo "STARTED pipeline PID=$! unclassified=$UNCL log=$LOG"
else
  echo "SKIP pipeline backlog bas unclassified=$UNCL (<$THRESHOLD)"
fi

if ! pgrep -f 'scripts/report_vision_element_loop\.sh' >/dev/null 2>&1; then
  rm -f "$LOG_DIR/stop_element_reports"
  nohup bash "$ROOT/scripts/report_vision_element_loop.sh" \
    >"$LOG_DIR/element_loop.out" 2>&1 &
  echo "STARTED element CR loop PID=$!"
else
  echo "SKIP element loop déjà actif"
fi

# Notification Element (best-effort)
if [ -x "$ROOT/scripts/send_element_via_140.sh" ]; then
  {
    echo "🔄 Reprise post-reboot (.10) — $(date '+%H:%M')"
    echo "• unclassified: ${UNCL}"
    echo "• pipeline: $([ "$RUNNING" -eq 1 ] && echo déjà actif || ([ "$UNCL" -ge "$THRESHOLD" ] && echo relancé || echo arrêté backlog bas))"
    echo "• CR Element: relancé si absent"
    bash "$ROOT/scripts/vision_pipeline_status.sh" 2>/dev/null || true
  } | bash "$ROOT/scripts/send_element_via_140.sh" 2>/dev/null || echo "element notify skip"
fi

echo "RESUME_DONE $(date -Is)"
