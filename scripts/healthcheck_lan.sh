#!/usr/bin/env bash
# Healthcheck LAN — 110 (proxy) et 140 (ComfyUI direct).
set -euo pipefail

FRONT="${LBG_HOST_FRONT:-192.168.0.110}"
CORE="${LBG_HOST_CORE:-192.168.0.140}"
USER="${LBG_VM_USER:-lbg}"

check_url() {
  local name="$1" url="$2"
  printf "%-20s " "${name}"
  if curl -sf --connect-timeout 5 "${url}" >/dev/null 2>&1; then
    echo "OK  ${url}"
    return 0
  else
    echo "FAIL ${url}"
    return 1
  fi
}

echo "=== Infographiste IA — healthcheck LAN ==="
FAIL=0
check_url "140 ComfyUI" "http://${CORE}:8188/system_stats" || { echo "  (normal si pas de GPU / ComfyUI non installé)"; }
check_url "110 proxy" "http://${FRONT}:8189/system_stats" || { echo "  (normal si proxy non configuré)"; }
check_url "110 Ollama" "http://${FRONT}:11434/api/tags" || FAIL=1

if ssh -o ConnectTimeout=5 -o BatchMode=yes "${USER}@${CORE}" 'nvidia-smi -L' 2>/dev/null; then
  echo "140 GPU: OK"
else
  echo "140 GPU: aucun (attendu pour l'instant)"
fi

exit "${FAIL}"
