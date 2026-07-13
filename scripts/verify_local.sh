#!/usr/bin/env bash
# Vérifie que le mode LOCAL (PC GPU) est opérationnel.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${PROJECT_DIR}/.env" ]]; then
  set -a; source "${PROJECT_DIR}/.env"; set +a
fi

COMFY_URL="${COMFY_LOCAL_URL:-http://172.24.160.1:8188}"
DATA_ROOT="${DATA_ROOT:-/mnt/b/Infographiste_IA}"
FAIL=0

ok() { echo "  OK   $1"; }
ko() { echo "  FAIL $1"; FAIL=1; }

echo "=== Infographiste IA — vérification mode LOCAL (PC GPU) ==="
echo ""

# Mode
if [[ "${INFRA_MODE:-LOCAL}" == "LOCAL" ]]; then
  ok "INFRA_MODE=LOCAL"
else
  ko "INFRA_MODE=${INFRA_MODE:-?} (attendu LOCAL)"
fi

# B: monté
if mountpoint -q /mnt/b 2>/dev/null && [[ -d "${DATA_ROOT}" ]]; then
  ok "Stockage B: ${DATA_ROOT}"
else
  ko "B: non monté — lancer: ./scripts/setup_data_drive.sh"
fi

# ComfyUI Windows
if curl -sf --connect-timeout 5 "${COMFY_URL}/system_stats" >/dev/null 2>&1; then
  ok "ComfyUI ${COMFY_URL}"
else
  ko "ComfyUI injoignable ${COMFY_URL} — lancer ComfyUI Windows (--listen 0.0.0.0 --lowvram)"
fi

# LoRA déployé
LORA_COMFY="/mnt/c/Users/sdesh/ComfyUI/models/loras/mmorpg_insp_lora.safetensors"
LORA_B="${DATA_ROOT}/lora/mmorpg_insp_lora.safetensors"
if [[ -f "${LORA_COMFY}" ]] || [[ -f "${LORA_B}" ]]; then
  ok "LoRA mmorpg_insp_lora.safetensors"
else
  echo "  WARN LoRA mmorpg_insp_lora absent (optionnel)"
fi

# venv Python
if [[ -f "${PROJECT_DIR}/.venv/bin/activate" ]]; then
  ok "venv Python"
else
  ko "venv absent — ./scripts/bootstrap_venv.sh"
fi

# NAS inspiration (optionnel)
if [[ -L "${PROJECT_DIR}/dataset/inspiration_mmorpg" ]] || [[ -d "${PROJECT_DIR}/dataset/inspiration_mmorpg" ]]; then
  ok "Dataset inspiration"
else
  echo "  WARN dataset/inspiration_mmorpg — ./scripts/mount_nas_dataset.sh"
fi

echo ""
if [[ "${FAIL}" -eq 0 ]]; then
  echo "Prêt pour génération locale."
  echo ""
  echo "  python orchestrator.py generate \\"
  echo "    --workflow workflows/workflow_sd15_lora_refined.json \\"
  echo "    --prompt \"mmorpg_insp, small floating steampunk drone\" \\"
  echo "    --lora mmorpg_insp_lora.safetensors"
else
  echo "Corrigez les FAIL ci-dessus."
fi
exit "${FAIL}"
