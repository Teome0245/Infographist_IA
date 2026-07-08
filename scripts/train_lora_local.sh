#!/usr/bin/env bash
set -euo pipefail

# Script "wrapper" : appelle un entraînement LoRA local (ex: kohya_ss).
# Tu peux l'intégrer dans ton pipeline build.
#
# Usage exemple:
#   ./scripts/train_lora_local.sh \
#     --kohya-dir /opt/kohya_ss \
#     --dataset-dir dataset \
#     --out-dir lora \
#     --name my_lora \
#     --base-model /models/sdxl_base.safetensors

KOHYA_DIR=""
DATASET_DIR="dataset"
OUT_DIR="lora"
NAME="lora_run"
BASE_MODEL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kohya-dir) KOHYA_DIR="$2"; shift 2 ;;
    --dataset-dir) DATASET_DIR="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --base-model) BASE_MODEL="$2"; shift 2 ;;
    *) echo "Argument inconnu: $1" ; exit 1 ;;
  esac
done

if [[ -z "${KOHYA_DIR}" ]]; then
  echo "Erreur: --kohya-dir requis (chemin vers kohya_ss)."
  exit 1
fi
if [[ -z "${BASE_MODEL}" ]]; then
  echo "Erreur: --base-model requis (checkpoint de base)."
  exit 1
fi

mkdir -p "${OUT_DIR}"

# IMPORTANT:
# - Les paramètres ci-dessous sont un point de départ "safe".
# - Adapte en fonction de ton modèle (SDXL/Flux), résolutions, captioning, etc.

cd "${KOHYA_DIR}"

python3 ./train_network.py \
  --pretrained_model_name_or_path "${BASE_MODEL}" \
  --train_data_dir "$(realpath "../${DATASET_DIR}")" \
  --output_dir "$(realpath "../${OUT_DIR}")" \
  --output_name "${NAME}" \
  --network_module "networks.lora" \
  --network_dim 32 \
  --learning_rate 1e-4 \
  --train_batch_size 1 \
  --max_train_epochs 10 \
  --mixed_precision "bf16" \
  --save_every_n_epochs 1

echo "OK: LoRA générée dans ${OUT_DIR}/${NAME}.safetensors (selon kohya)."

