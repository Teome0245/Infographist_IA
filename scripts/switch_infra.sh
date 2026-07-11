#!/usr/bin/env bash
# Bascule LOCAL <-> DISTRIBUTED (poste dev).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODE="${1:-}"

usage() {
  echo "Usage: $0 {local|distributed|status}"
  exit 1
}

[[ -n "${MODE}" ]] || usage

case "${MODE}" in
  local)
    if [[ -f "${PROJECT_DIR}/.env" ]]; then
      cp "${PROJECT_DIR}/.env" "${PROJECT_DIR}/.env.bak.$(date +%Y%m%d%H%M%S)"
    fi
    cp "${PROJECT_DIR}/config/.env.local.example" "${PROJECT_DIR}/.env"
    sed -i 's/\r$//' "${PROJECT_DIR}/.env"
    echo "Mode LOCAL activé (GPU PC Windows, VMs sans rendu)."
    ;;
  distributed)
    cp "${PROJECT_DIR}/config/.env.distributed.example" "${PROJECT_DIR}/.env"
    sed -i 's/\r$//' "${PROJECT_DIR}/.env"
    echo "Mode DISTRIBUTED activé (110/140)."
    ;;
  status)
    if [[ -f "${PROJECT_DIR}/.env" ]]; then
      grep -E '^INFRA_MODE=|^INFRA_TARGET=|^COMFY_' "${PROJECT_DIR}/.env" || true
    else
      echo "Pas de .env"
    fi
    exit 0
    ;;
  *) usage ;;
esac

cd "${PROJECT_DIR}"
source .venv/bin/activate 2>/dev/null || true
python -c "
from infographiste_virtuel.config import load_config
c = load_config()
print('Mode:', c.infra.mode)
print('Endpoint:', c.comfy_base_url())
" 2>/dev/null || echo "(venv non activé — source .venv/bin/activate)"
