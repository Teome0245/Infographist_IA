#!/usr/bin/env bash
# Genere une serie Pygmalion v2 centree sur la finesse des visages.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"
source .venv/bin/activate

WORKFLOW="${WORKFLOW:-workflows/workflow_sd15_lora_refined.json}"
LORA="${LORA:-mmorpg_insp_lora.safetensors}"
OUT="${OUT:-${PROJECT_DIR}/assets/images}"

NEG="${NEG:-blurry, low quality, deformed face, asymmetrical eyes, bad anatomy, bad hands, extra fingers, extra limbs, cropped, close-up portrait crop, plastic skin, waxy skin, anime, manga, chibi, watermark, text, logo}"

mkdir -p "${OUT}"

SEEDS=(3401 3402 3403)
PROMPTS=(
  "mmorpg_insp, full body character sheet, fantasy MMO scout, neutral studio background, refined facial features, sharp eyes, natural lips, subtle skin texture, intricate leather stitching, layered cloth, polished buckles, game-ready concept art"
  "mmorpg_insp, full body character concept, arcane duelist, neutral background, elegant face, balanced facial proportions, soft realistic skin detail, ornate accessories, detailed sleeves, fitted boots, costume concept art"
  "mmorpg_insp, full body character sheet, beastkin ranger, neutral background, expressive face, detailed eyes, nuanced fur and fabric transition, belt pouches, straps, layered armor-cloth mix, clean silhouette"
)

for seed in "${SEEDS[@]}"; do
  for prompt in "${PROMPTS[@]}"; do
    echo "=== character_v2 seed=${seed} ==="
    python orchestrator.py generate \
      --workflow "${WORKFLOW}" \
      --prompt "${prompt}" \
      --negative-prompt "${NEG}" \
      --lora "${LORA}" \
      --seed "${seed}" \
      --output-dir "${OUT}"
  done
done
