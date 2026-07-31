#!/usr/bin/env bash
# Regénère uniquement les NPC (style unifié) — rapide.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT="${OUTPUT:-/mnt/b/Infographiste_IA/pipelines/2d/outputs/units}"
PROMPTS="${PROJECT_DIR}/pipelines/2d/prompts"
WORKFLOW="${PROJECT_DIR}/workflows/workflow_sd15_lora_refined.json"
BASE="$(tr -d '\n' < "${PROMPTS}/style_base.txt")"
NEG="$(tr -d '\n' < "${PROMPTS}/style_negative.txt")"
cd "${PROJECT_DIR}" && source .venv/bin/activate
gen() {
  python orchestrator.py generate --workflow "${WORKFLOW}" \
    --prompt "${BASE}, $2" --negative-prompt "${NEG}" \
    --lora mmorpg_insp_lora.safetensors --seed "$3" --output-dir "${OUTPUT}"
  mv -f "$(ls -t "${OUTPUT}"/mmorpg_refined_*.png | head -1)" "${OUTPUT}/$1.png"
}
gen npc_default "civilian npc, simple desert clothes, unarmed, standing idle" 51002
gen npc_guard "guard npc, light steampunk armor, compact helmet, standing alert" 51003
echo "OK NPC — ./scripts/deploy_sprites_to_prime.sh"
