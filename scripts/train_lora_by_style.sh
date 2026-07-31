#!/usr/bin/env bash
# Entraîne un LoRA SD1.5 par profil de style (kohya_train_by_style/{repeats}_{trigger}).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${PROJECT_DIR}/.env" ]]; then
  set -a; source "${PROJECT_DIR}/.env"; set +a
fi

# Staging C: pour entraînement par style (copies réelles). B: drvfs pose des problèmes de droits.
DATA_ROOT_WIN="C:\\Users\\sdesh\\Infographiste_IA_data"
DATA_ROOT_WSL="/mnt/c/Users/sdesh/Infographiste_IA_data"
PYTHON="C:\\Users\\sdesh\\ComfyUI\\venv\\Scripts\\python.exe"
BASE_MODEL="C:/Users/sdesh/ComfyUI/models/checkpoints/DreamShaper_8_pruned.safetensors"
COMFY_LORA_DIR="/mnt/c/Users/sdesh/ComfyUI/models/loras"

STYLE=""
EPOCHS=3
NETWORK_DIM=16
DEPLOY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --style) STYLE="$2"; shift 2 ;;
    --epochs) EPOCHS="$2"; shift 2 ;;
    --network-dim) NETWORK_DIM="$2"; shift 2 ;;
    --deploy) DEPLOY=1; shift ;;
    *) echo "Argument inconnu: $1"; exit 1 ;;
  esac
done

if [[ -z "${STYLE}" ]]; then
  echo "Usage: $0 --style mmorpg_general|prime_sprite_2d|map_topdown [--deploy]"
  exit 1
fi

read -r TRIGGER REPEATS OUTPUT_NAME KOHYA_FOLDER <<<"$(
  python3 - <<PY
import json
from pathlib import Path
doc = json.loads(Path("${PROJECT_DIR}/config/art_styles.json").read_text())
cfg = (doc.get("styles") or {}).get("${STYLE}", {}).get("lora") or {}
trigger = cfg.get("trigger_word") or "${STYLE}"
repeats = int(cfg.get("repeats") or 10)
out = cfg.get("output_name") or f"{trigger}_lora.safetensors"
print(trigger, repeats, out, f"{repeats}_{trigger}")
PY
)"

NAME="${OUTPUT_NAME%.safetensors}"
SINGLE_WSL="${DATA_ROOT_WSL}/kohya_train_by_style/_single_${STYLE}"
SINGLE_WIN="${DATA_ROOT_WIN}\\kohya_train_by_style\\_single_${STYLE}"
SOURCE_WSL="${DATA_ROOT_WSL}/kohya_train_by_style/${KOHYA_FOLDER}"
OUT_DIR="${DATA_ROOT_WIN}\\lora"
LOG="${DATA_ROOT_WIN}\\logs\\train_${STYLE}.log"

if [[ ! -d "${SOURCE_WSL}" ]]; then
  echo "Erreur: dataset absent ${SOURCE_WSL}"
  echo "Lance: python orchestrator.py prepare-styles --from-sorted dataset/styles_sorted --json"
  exit 1
fi
if [[ ! -d "/mnt/c/Users/sdesh/kohya_ss" ]]; then
  echo "Erreur: kohya_ss absent dans C:\\Users\\sdesh\\kohya_ss"
  exit 1
fi

rm -rf "${SINGLE_WSL}"
mkdir -p "${SINGLE_WSL}/${KOHYA_FOLDER}"
# Copie réelle (Windows ne suit pas les symlinks créés par WSL)
echo "Copie dataset → ${SINGLE_WSL}/${KOHYA_FOLDER} ..."
cp -a "${SOURCE_WSL}/." "${SINGLE_WSL}/${KOHYA_FOLDER}/"
mkdir -p "${DATA_ROOT_WSL}/logs" 2>/dev/null || true
IMG_COUNT=$(find "${SINGLE_WSL}/${KOHYA_FOLDER}" -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' \) | wc -l)
echo "Images dans le dossier train: ${IMG_COUNT}"
if [[ "${IMG_COUNT}" -lt 5 ]]; then
  echo "Erreur: trop peu d'images dans ${SINGLE_WSL}/${KOHYA_FOLDER}"
  exit 1
fi

echo "=== Entraînement LoRA style=${STYLE} → ${NAME} (${EPOCHS} epochs) ==="
echo "Dataset : ${SINGLE_WIN}"
echo "Sortie  : ${OUT_DIR}"
echo "Logs    : ${LOG}"
echo "Ferme ComfyUI pour libérer la VRAM."
echo ""

cmd.exe /c "cd /d C:\\Users\\sdesh\\kohya_ss && ${PYTHON} -X utf8 train_network.py \
  --pretrained_model_name_or_path ${BASE_MODEL} \
  --train_data_dir ${SINGLE_WIN} \
  --output_dir ${OUT_DIR} \
  --output_name ${NAME} \
  --save_model_as safetensors \
  --network_module networks.lora \
  --network_dim ${NETWORK_DIM} \
  --network_alpha ${NETWORK_DIM} \
  --learning_rate 1e-4 \
  --optimizer_type AdamW8bit \
  --train_batch_size 1 \
  --max_train_epochs ${EPOCHS} \
  --save_every_n_epochs 1 \
  --mixed_precision fp16 \
  --save_precision fp16 \
  --cache_latents \
  --gradient_checkpointing \
  --resolution 512 \
  --enable_bucket \
  --min_bucket_reso 256 \
  --max_bucket_reso 512 \
  --caption_extension .txt \
  --keep_tokens 1 \
  --seed 42 \
  > ${LOG} 2>&1"

LORA_FILE="${DATA_ROOT_WSL}/lora/${NAME}.safetensors"
if [[ ! -f "${LORA_FILE}" ]]; then
  echo "Erreur: LoRA non générée. Dernières lignes du log :"
  tail -20 "${DATA_ROOT_WSL}/logs/train_${STYLE}.log" 2>/dev/null || true
  exit 1
fi

echo "OK: ${LORA_FILE} ($(du -h "${LORA_FILE}" | cut -f1))"

if [[ "${DEPLOY}" == "1" ]]; then
  mkdir -p "${COMFY_LORA_DIR}"
  cp "${LORA_FILE}" "${COMFY_LORA_DIR}/"
  echo "Copie vers ComfyUI: ${COMFY_LORA_DIR}/${NAME}.safetensors"
fi
