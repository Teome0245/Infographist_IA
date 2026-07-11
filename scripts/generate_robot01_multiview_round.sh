#!/usr/bin/env bash
# Multi-view drone steampunk — variante RONDE (Gunnm/Alita, orb flottant).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

OUTPUT="${OUTPUT:-/mnt/b/Infographiste_IA/pipelines/3d/outputs/multiview/robot01_round}"
WORKFLOW="${PROJECT_DIR}/workflows/workflow_sd15_lora_refined.json"
LORA="mmorpg_insp_lora.safetensors"
BASE_SEED="${BASE_SEED:-42101}"

BASE_PROMPT="mmorpg_insp, small round floating orb drone, spherical body, compact ball shape, steampunk light cyberpunk, gunnm alita vibe, retro 80s anime, single large mono-eye lens on sphere, brass and painted steel panels, rivets, small exhaust pipes, tiny stabilizer fins, no legs no arms no humanoid, floating hover, stylized semi-realistic, neutral grey background, studio lighting, sharp focus, clean silhouette"

NEGATIVE="blurry, messy, cluttered, angular, boxy, humanoid, legs, arms, hands, character, extra parts, deformed, low quality, watermark, text"

mkdir -p "${OUTPUT}"
cd "${PROJECT_DIR}"
source .venv/bin/activate

cp -f /mnt/b/Infographiste_IA/lora/mmorpg_insp_lora.safetensors \
  /mnt/c/Users/sdesh/ComfyUI/models/loras/ 2>/dev/null || true

generate_view() {
  local name="$1"
  local view_prompt="$2"
  local seed="$3"
  echo ""
  echo "=== ${name} (seed ${seed}) ==="
  python orchestrator.py generate \
    --workflow "${WORKFLOW}" \
    --prompt "${BASE_PROMPT}, ${view_prompt}" \
    --negative-prompt "${NEGATIVE}" \
    --lora "${LORA}" \
    --seed "${seed}" \
    --output-dir "${OUTPUT}"
  local latest
  latest=$(ls -t "${OUTPUT}"/mmorpg_refined_*.png 2>/dev/null | head -1)
  if [[ -n "${latest}" && -f "${latest}" ]]; then
    mv -f "${latest}" "${OUTPUT}/robot01_round_${name}.png"
    echo "OK: ${OUTPUT}/robot01_round_${name}.png"
  fi
}

echo "Variante: drone ROND (Gunnm/Alita)"
echo "Sortie: ${OUTPUT}"

generate_view "front" "front view, centered, spherical orb, orthographic-like, symmetrical" "${BASE_SEED}"
generate_view "side" "left side view, profile, perfect circle silhouette, orthographic-like" "$((BASE_SEED + 1))"
generate_view "back" "back view, rear, spherical orb, orthographic-like" "$((BASE_SEED + 2))"
generate_view "3q" "three-quarter view, floating orb, turntable angle" "$((BASE_SEED + 3))"

echo ""
echo "=== Passe drone rond terminée ==="
ls -lh "${OUTPUT}"/robot01_round_*.png
