#!/usr/bin/env bash
# Génère les 4 vues multi-view du drone steampunk robot01 (option A).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

OUTPUT="${OUTPUT:-/mnt/b/Infographiste_IA/pipelines/3d/outputs/multiview/robot01}"
WORKFLOW="${PROJECT_DIR}/workflows/workflow_sd15_lora_refined.json"
LORA="mmorpg_insp_lora.safetensors"
BASE_SEED="${BASE_SEED:-42001}"

BASE_PROMPT="mmorpg_insp, small floating steampunk drone robot, light cyberpunk, retro-futuristic 80s anime, cowboy bebop vibe, gunnm vibe, compact readable silhouette, mono-eye camera, brass and painted steel, worn edges, bolts, rivets, small pipes, utility backpack, stylized semi-realistic, neutral grey background, studio lighting, sharp focus, clean design"

NEGATIVE="blurry, messy, cluttered, extra parts, deformed, low quality, watermark, text, humanoid, legs, arms, character"

mkdir -p "${OUTPUT}"
cd "${PROJECT_DIR}"
source .venv/bin/activate

# Déployer LoRA latest
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
  # Renommer le dernier fichier généré
  local latest
  latest=$(ls -t "${OUTPUT}"/mmorpg_refined_*.png 2>/dev/null | head -1)
  if [[ -n "${latest}" && -f "${latest}" ]]; then
    mv -f "${latest}" "${OUTPUT}/robot01_${name}.png"
    echo "OK: ${OUTPUT}/robot01_${name}.png"
  fi
}

echo "Sortie: ${OUTPUT}"
echo "Workflow: workflow_sd15_lora_refined.json"
echo "LoRA: ${LORA}"

generate_view "front" "front view, centered, full body, orthographic-like, symmetrical" "${BASE_SEED}"
generate_view "side" "left side view, profile, orthographic-like, full body" "$((BASE_SEED + 1))"
generate_view "back" "back view, rear, orthographic-like, full body" "$((BASE_SEED + 2))"
generate_view "3q" "three-quarter view, slight angle, turntable pose" "$((BASE_SEED + 3))"

echo ""
echo "=== Multi-view robot01 terminé ==="
ls -lh "${OUTPUT}"/robot01_*.png
