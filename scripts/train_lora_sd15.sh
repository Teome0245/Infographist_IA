#!/usr/bin/env bash
# Entraîne un LoRA SD1.5 (DreamShaper) — profil GTX 1050 Ti 4 Go VRAM.
# Nécessite kohya_ss installé (voir docs/TRAIN_LORA.md).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

KOHYA_DIR="${KOHYA_DIR:-/mnt/c/Users/sdesh/kohya_ss}"
DATASET_DIR="${DATASET_DIR:-${PROJECT_DIR}/dataset/kohya_train}"
OUT_DIR="${OUT_DIR:-${PROJECT_DIR}/lora}"
NAME="${NAME:-mmorpg_insp_lora}"
BASE_MODEL="${BASE_MODEL:-/mnt/c/Users/sdesh/ComfyUI/models/checkpoints/DreamShaper_8_pruned.safetensors}"
COMFY_LORA_DIR="${COMFY_LORA_DIR:-/mnt/c/Users/sdesh/ComfyUI/models/loras}"
EPOCHS="${EPOCHS:-5}"
NETWORK_DIM="${NETWORK_DIM:-16}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kohya-dir) KOHYA_DIR="$2"; shift 2 ;;
    --dataset-dir) DATASET_DIR="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --base-model) BASE_MODEL="$2"; shift 2 ;;
    --epochs) EPOCHS="$2"; shift 2 ;;
    --network-dim) NETWORK_DIM="$2"; shift 2 ;;
    --deploy) DEPLOY=1; shift ;;
    *) echo "Argument inconnu: $1"; exit 1 ;;
  esac
done

if [[ ! -d "${KOHYA_DIR}" ]]; then
  echo "Erreur: kohya_ss introuvable dans ${KOHYA_DIR}"
  echo "Installe-le avec: powershell.exe -File scripts/windows/install_kohya_windows.ps1"
  exit 1
fi
if [[ ! -f "${BASE_MODEL}" ]]; then
  echo "Erreur: checkpoint introuvable: ${BASE_MODEL}"
  exit 1
fi
if [[ ! -d "${DATASET_DIR}" ]]; then
  echo "Erreur: dataset Kohya introuvable. Lance d'abord: ./scripts/prepare_kohya_dataset.sh"
  exit 1
fi

mkdir -p "${OUT_DIR}"

cd "${KOHYA_DIR}"

# Profil conservateur 4 Go VRAM (Pascal GTX 1050 Ti — fp16, pas bf16)
python train_network.py \
  --pretrained_model_name_or_path "${BASE_MODEL}" \
  --train_data_dir "${DATASET_DIR}" \
  --output_dir "${OUT_DIR}" \
  --output_name "${NAME}" \
  --save_model_as safetensors \
  --network_module networks.lora \
  --network_dim "${NETWORK_DIM}" \
  --network_alpha "${NETWORK_DIM}" \
  --learning_rate 1e-4 \
  --unet_lr 1e-4 \
  --text_encoder_lr 5e-5 \
  --optimizer_type AdamW8bit \
  --lr_scheduler cosine \
  --lr_warmup_steps 100 \
  --train_batch_size 1 \
  --max_train_epochs "${EPOCHS}" \
  --save_every_n_epochs 1 \
  --mixed_precision fp16 \
  --save_precision fp16 \
  --cache_latents \
  --gradient_checkpointing \
  --xformers \
  --resolution 512 \
  --enable_bucket \
  --min_bucket_reso 256 \
  --max_bucket_reso 512 \
  --bucket_reso_steps 64 \
  --caption_extension .txt \
  --shuffle_caption \
  --keep_tokens 1 \
  --seed 42

LORA_FILE="${OUT_DIR}/${NAME}.safetensors"
echo ""
echo "OK: LoRA entraînée -> ${LORA_FILE}"

if [[ "${DEPLOY:-0}" == "1" ]]; then
  mkdir -p "${COMFY_LORA_DIR}"
  cp "${LORA_FILE}" "${COMFY_LORA_DIR}/"
  echo "Déployée vers ComfyUI: ${COMFY_LORA_DIR}/${NAME}.safetensors"
  echo ""
  echo "Génération avec LoRA:"
  echo "  python orchestrator.py generate \\"
  echo "    --workflow workflows/workflow_sd15_lora_lowvram.json \\"
  echo "    --prompt \"mmorpg_insp, paysage fantasy brumeux, ruines anciennes\" \\"
  echo "    --lora \"${NAME}.safetensors\""
fi
