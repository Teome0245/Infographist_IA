#!/usr/bin/env bash
# Genere une serie Pygmalion v1 orientee character sheets.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"
source .venv/bin/activate

WORKFLOW="${WORKFLOW:-workflows/workflow_sd15_lora_refined.json}"
LORA="${LORA:-mmorpg_insp_lora.safetensors}"
OUT="${OUT:-${PROJECT_DIR}/assets/images}"

NEG="${NEG:-blurry, low quality, deformed face, asymmetrical eyes, bad anatomy, bad hands, extra fingers, extra limbs, cropped, close-up, watermark, text, logo, anime, manga, chibi}"

mkdir -p "${OUT}"

SEEDS=(1401 1402 1403)
PROMPTS=(
  "mmorpg_insp, full body character sheet, fantasy MMO pathfinder scout, neutral studio background, clean silhouette, refined facial features, sharp eyes, subtle skin detail, intricate clothing seams, layered materials, game-ready concept art"
  "mmorpg_insp, full body character concept, arcane duelist, neutral background, polished accessories, ornate belt details, refined facial features, subtle skin texture, elegant costume materials"
  "mmorpg_insp, turnaround-style character sheet, beastkin ranger, neutral background, expressive face, high-detail costume layers, belt pouches, buckles, cloth folds, clean silhouette"
)

for seed in "${SEEDS[@]}"; do
  for prompt in "${PROMPTS[@]}"; do
    echo "=== character_v1 seed=${seed} ==="
    python orchestrator.py generate \
      --workflow "${WORKFLOW}" \
      --prompt "${prompt}" \
      --negative-prompt "${NEG}" \
      --lora "${LORA}" \
      --seed "${seed}" \
      --output-dir "${OUT}"
  done
done
