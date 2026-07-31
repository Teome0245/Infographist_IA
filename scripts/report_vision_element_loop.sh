#!/usr/bin/env bash
# Compte-rendu Element régulier tant que le pipeline vision tourne.
# Intervalle: INFOGRAPHISTE_ELEMENT_REPORT_S (défaut 900 = 15 min)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTERVAL="${INFOGRAPHISTE_ELEMENT_REPORT_S:-900}"
STATUS="$ROOT/scripts/vision_pipeline_status.sh"
SEND="$ROOT/scripts/send_element_via_140.sh"
LOG="${INFOGRAPHISTE_ELEMENT_REPORT_LOG:-/tmp/infographiste_logs/element_reports.log}"
mkdir -p "$(dirname "$LOG")"

send_once() {
  local kind="$1"
  local body
  export INFOGRAPHISTE_CR_VERBOSE="${INFOGRAPHISTE_CR_VERBOSE:-1}"
  body="$("$STATUS" 2>/dev/null || echo 'statut indisponible')"
  local msg
  msg=$(printf '%s\n\n%s' "📡 CR Infographiste — ${kind}" "$body")
  # petit délai anti-rate-limit Synapse LAN
  sleep "${INFOGRAPHISTE_ELEMENT_SEND_DELAY_S:-2}"
  if bash "$SEND" "$msg" >>"$LOG" 2>&1; then
    echo "$(date -Is) OK ${kind}" >>"$LOG"
    return 0
  fi
  echo "$(date -Is) FAIL ${kind}" >>"$LOG"
  return 1
}

echo "START_REPORT_LOOP $(date -Is) interval=${INTERVAL}s" >>"$LOG"
send_once "démarrage" || true

while true; do
  sleep "$INTERVAL"
  # Arrêt si plus de pipeline ET unclassified déjà bas, ou flag stop
  if [ -f /tmp/infographiste_logs/stop_element_reports ]; then
    send_once "stop demandé" || true
    echo "STOP_FLAG $(date -Is)" >>"$LOG"
    break
  fi
  running=0
  pgrep -f 'orchestrator\.py vision-classify' >/dev/null 2>&1 && running=1
  pgrep -f 'scripts/run_vision_prepare_pipeline\.sh' >/dev/null 2>&1 && running=1
  if [ "$running" -eq 0 ]; then
    send_once "pipeline terminé / idle" || true
    echo "STOP_IDLE $(date -Is)" >>"$LOG"
    break
  fi
  send_once "périodique" || true
done
echo "END_REPORT_LOOP $(date -Is)" >>"$LOG"
