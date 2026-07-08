#!/usr/bin/env bash
# Prépare le dataset NAS au format Kohya (sd-scripts).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

SOURCE="${SOURCE:-${PROJECT_DIR}/dataset/inspiration_mmorpg}"
OUTPUT="${OUTPUT:-${PROJECT_DIR}/dataset/kohya_train}"
REPEATS="${REPEATS:-10}"
TRIGGER="${TRIGGER:-mmorpg_insp}"
MAX_IMAGES="${MAX_IMAGES:-}"

cd "${PROJECT_DIR}"
source .venv/bin/activate

ARGS=(
  --source "${SOURCE}"
  --output "${OUTPUT}"
  --repeats "${REPEATS}"
  --trigger "${TRIGGER}"
)
if [[ -n "${MAX_IMAGES}" ]]; then
  ARGS+=(--max-images "${MAX_IMAGES}")
fi

python orchestrator.py prepare-dataset "${ARGS[@]}"

echo ""
echo "Prochaine étape : entraînement LoRA"
echo "  ./scripts/train_lora_sd15.sh --name mmorpg_insp_lora"
