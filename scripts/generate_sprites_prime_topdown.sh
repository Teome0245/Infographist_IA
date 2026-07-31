#!/usr/bin/env bash
# Génère sprites Prime avec style unifié (voir pipelines/2d/STYLE_PRIME.md).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROMPTS="${PROJECT_DIR}/pipelines/2d/prompts"

OUTPUT="${OUTPUT:-/mnt/b/Infographiste_IA/pipelines/2d/outputs/units}"
WORKFLOW="${PROJECT_DIR}/workflows/workflow_sd15_lora_refined.json"
LORA="mmorpg_insp_lora.safetensors"

BASE="$(tr -d '\n' < "${PROMPTS}/style_base.txt")"
NEG="$(tr -d '\n' < "${PROMPTS}/style_negative.txt")"

mkdir -p "${OUTPUT}"
cd "${PROJECT_DIR}"
source .venv/bin/activate

cp -f /mnt/b/Infographiste_IA/lora/mmorpg_insp_lora.safetensors \
  /mnt/c/Users/sdesh/ComfyUI/models/loras/ 2>/dev/null || true

gen_one() {
  local name="$1"
  local extra="$2"
  local seed="$3"
  echo ""
  echo "=== ${name} (seed ${seed}) ==="
  python orchestrator.py generate \
    --workflow "${WORKFLOW}" \
    --prompt "${BASE}, ${extra}" \
    --negative-prompt "${NEG}" \
    --lora "${LORA}" \
    --seed "${seed}" \
    --output-dir "${OUTPUT}"
  local latest
  latest=$(ls -t "${OUTPUT}"/mmorpg_refined_*.png 2>/dev/null | head -1)
  if [[ -n "${latest}" && -f "${latest}" ]]; then
    mv -f "${latest}" "${OUTPUT}/${name}.png"
    echo "OK: ${OUTPUT}/${name}.png"
  fi
}

# Joueurs
gen_one "player_lia" "female explorer, green desert cloak, slim silhouette" 51101
gen_one "player_nix" "male scout, blue tech gear, compact silhouette" 51102
gen_one "player_mira" "female pilot, magenta accent jacket" 51103
gen_one "player_teome" "male hero lead, blue official coat" 51104
gen_one "player_gally" "male mechanic, ochre work suit" 51105
gen_one "player_kael" "male fighter, violet armor trim" 51106
gen_one "player_bot" "neutral explorer gear, standing idle" 51001

# NPC — même style token
gen_one "npc_default" "civilian npc, simple desert clothes, unarmed, standing idle" 51002
gen_one "npc_guard" "guard npc, light steampunk armor, compact helmet, standing alert" 51003

echo ""
echo "Style unifié — déployer : ./scripts/deploy_sprites_to_prime.sh"
