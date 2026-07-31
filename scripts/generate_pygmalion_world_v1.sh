#!/usr/bin/env bash
# Genere une serie Pygmalion v1 orientee worldbuilding/cartographie.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"
source .venv/bin/activate

WORKFLOW="${WORKFLOW:-workflows/workflow_sd15_lora_refined.json}"
LORA="${LORA:-mmorpg_insp_lora.safetensors}"
OUT="${OUT:-${PROJECT_DIR}/assets/images}"

NEG="${NEG:-modern skyscraper, car, highway, realistic photograph, blurry, portrait, close-up face, single centered character, watermark, logo, unreadable text block}"

mkdir -p "${OUT}"

SEEDS=(2401 2402 2403)
PROMPTS=(
  "mmorpg_insp, hand-drawn fantasy world map on parchment, clear coastlines, mountain ranges, forests, biomes, compass rose, readable cartography style, no modern elements"
  "mmorpg_insp, bird's-eye fantasy city layout, districts, walls, harbor, roads, landmark buildings, strategy map style, no skyscrapers"
  "mmorpg_insp, regional adventure map with ruins, villages, forests, shrines, roads, annotated icon style, tabletop RPG cartography"
)

for seed in "${SEEDS[@]}"; do
  for prompt in "${PROMPTS[@]}"; do
    echo "=== world_v1 seed=${seed} ==="
    python orchestrator.py generate \
      --workflow "${WORKFLOW}" \
      --prompt "${prompt}" \
      --negative-prompt "${NEG}" \
      --lora "${LORA}" \
      --seed "${seed}" \
      --output-dir "${OUT}"
  done
done
