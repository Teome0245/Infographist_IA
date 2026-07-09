#!/usr/bin/env bash
# Entraîne un LoRA SD1.5 via Python Windows — données sur B:.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${PROJECT_DIR}/.env" ]]; then
  set -a; source "${PROJECT_DIR}/.env"; set +a
fi

DATA_ROOT_WIN="${DATA_ROOT_WIN:-B:\\Infographiste_IA}"
PYTHON="C:\\Users\\sdesh\\ComfyUI\\venv\\Scripts\\python.exe"
BASE_MODEL="C:/Users/sdesh/ComfyUI/models/checkpoints/DreamShaper_8_pruned.safetensors"
COMFY_LORA_DIR="/mnt/c/Users/sdesh/ComfyUI/models/loras"

NAME="mmorpg_insp_lora"
EPOCHS=3
NETWORK_DIM=16
DEPLOY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --epochs) EPOCHS="$2"; shift 2 ;;
    --network-dim) NETWORK_DIM="$2"; shift 2 ;;
    --deploy) DEPLOY=1; shift ;;
    *) echo "Argument inconnu: $1"; exit 1 ;;
  esac
done

DATASET_DIR="${DATA_ROOT_WIN}\\kohya_train"
OUT_DIR="${DATA_ROOT_WIN}\\lora"
LOG="${DATA_ROOT_WIN}\\logs\\train.log"

if [[ ! -d "/mnt/c/Users/sdesh/kohya_ss" ]]; then
  echo "Erreur: kohya_ss absent dans C:\\Users\\sdesh\\kohya_ss"
  exit 1
fi
if [[ ! -d "${KOHYA_TRAIN_DIR:-/mnt/b/Infographiste_IA/kohya_train}" ]]; then
  echo "Erreur: dataset absent. Lance: ./scripts/prepare_kohya_dataset_windows.sh"
  exit 1
fi

mkdir -p "/mnt/b/Infographiste_IA/logs" 2>/dev/null || true

echo "=== Entraînement LoRA: ${NAME} (${EPOCHS} epochs) ==="
echo "Dataset : ${DATASET_DIR}"
echo "Sortie  : ${OUT_DIR}"
echo "Logs    : ${LOG}"
echo "Ferme ComfyUI pour libérer la VRAM."
echo ""

cmd.exe /c "cd /d C:\\Users\\sdesh\\kohya_ss && ${PYTHON} -X utf8 train_network.py \
  --pretrained_model_name_or_path ${BASE_MODEL} \
  --train_data_dir ${DATASET_DIR} \
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

LORA_FILE="/mnt/b/Infographiste_IA/lora/${NAME}.safetensors"
if [[ ! -f "${LORA_FILE}" ]]; then
  echo "Erreur: LoRA non générée. Dernières lignes du log :"
  tail -20 "/mnt/b/Infographiste_IA/logs/train.log" 2>/dev/null || true
  exit 1
fi

echo "OK: ${LORA_FILE} ($(du -h "${LORA_FILE}" | cut -f1))"

if [[ "${DEPLOY}" == "1" ]]; then
  mkdir -p "${COMFY_LORA_DIR}"
  cp "${LORA_FILE}" "${COMFY_LORA_DIR}/"
  echo "Copie vers ComfyUI: ${COMFY_LORA_DIR}/${NAME}.safetensors"
  echo ""
  echo "python orchestrator.py generate \\"
  echo "  --workflow workflows/workflow_sd15_lora_lowvram.json \\"
  echo "  --prompt \"mmorpg_insp, paysage fantasy brumeux, ruines anciennes\" \\"
  echo "  --lora \"${NAME}.safetensors\""
fi
