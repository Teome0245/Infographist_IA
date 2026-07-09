#!/usr/bin/env bash
# Prépare le dataset Kohya sur B: (copies locales pour Kohya Windows).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Charger .env si présent
if [[ -f "${PROJECT_DIR}/.env" ]]; then
  set -a; source "${PROJECT_DIR}/.env"; set +a
fi

SOURCE="${SOURCE:-${PROJECT_DIR}/dataset/inspiration_mmorpg}"
OUTPUT="${KOHYA_TRAIN_DIR:-/mnt/b/Infographiste_IA/kohya_train}"
REPEATS="${REPEATS:-3}"
TRIGGER="${TRIGGER:-mmorpg_insp}"
MAX_IMAGES="${MAX_IMAGES:-200}"

cd "${PROJECT_DIR}"
source .venv/bin/activate

echo "Source  : ${SOURCE}"
echo "Sortie  : ${OUTPUT}"
echo "Images  : ${MAX_IMAGES:-toutes}"
echo "Repeats : ${REPEATS}"
echo ""

ARGS=(
  --source "${SOURCE}"
  --output "${OUTPUT}"
  --repeats "${REPEATS}"
  --trigger "${TRIGGER}"
  --copy
)
if [[ -n "${MAX_IMAGES}" ]]; then
  ARGS+=(--max-images "${MAX_IMAGES}")
fi

python orchestrator.py prepare-dataset "${ARGS[@]}"

echo ""
echo "Dataset prêt sur B: → ${OUTPUT}"
echo "Entraînement : ./scripts/train_lora_sd15.sh --name mmorpg_insp_lora --deploy"
