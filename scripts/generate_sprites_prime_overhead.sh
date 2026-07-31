#!/usr/bin/env bash
# 2ᵉ passe — tokens strictement overhead (dos/épaules, pas portrait).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROMPTS="${PROJECT_DIR}/pipelines/2d/prompts"

OUTPUT="${OUTPUT:-${PROJECT_DIR}/pipelines/2d/outputs/units_overhead}"
WORKFLOW="${PROJECT_DIR}/workflows/workflow_sd15_lora_refined.json"
LORA="mmorpg_insp_lora.safetensors"
COMFY_URL="${COMFY_URL:-${COMFY_LOCAL_URL:-http://172.24.160.1:8188}}"

BASE="$(tr -d '\n' < "${PROMPTS}/style_base.txt")"
NEG="$(tr -d '\n' < "${PROMPTS}/style_negative.txt")"
NEG="${NEG}, front view, face visible, portrait, bust, three quarter view, isometric, side view, low angle, high angle, dynamic pose, running"

mkdir -p "${OUTPUT}"
cd "${PROJECT_DIR}"
if [[ ! -d .venv ]]; then
  echo "ERREUR: .venv Infographiste_IA absent" >&2
  exit 1
fi
# shellcheck disable=SC1091
source .venv/bin/activate

if ! curl -fsS -m 5 "${COMFY_URL}/system_stats" >/dev/null 2>&1; then
  echo "ComfyUI injoignable sur ${COMFY_URL} — lance Windows: python main.py --listen 0.0.0.0 --port 8188" >&2
  exit 2
fi

cp -f "${PROJECT_DIR}/lora/mmorpg_insp_lora.safetensors" \
  /mnt/c/Users/sdesh/ComfyUI/models/loras/ 2>/dev/null || \
cp -f /mnt/b/Infographiste_IA/lora/mmorpg_insp_lora.safetensors \
  /mnt/c/Users/sdesh/ComfyUI/models/loras/ 2>/dev/null || true

gen_one() {
  local name="$1"
  local extra="$2"
  local seed="$3"
  echo ""
  echo "=== overhead ${name} (seed ${seed}) ==="
  python orchestrator.py generate \
    --workflow "${WORKFLOW}" \
    --prompt "${BASE}, ${extra}, seen from directly above, back of head, circular base shadow" \
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

gen_one "player_lia" "female explorer, green desert cloak, compact token" 52101
gen_one "player_nix" "male scout, blue tech gear" 52102
gen_one "player_mira" "female pilot, magenta jacket trim" 52103
gen_one "player_teome" "male hero, blue official coat" 52104
gen_one "player_gally" "male mechanic, ochre work suit" 52105
gen_one "player_kael" "male fighter, violet armor trim" 52106
gen_one "player_bot" "neutral explorer gear, idle stance" 52001
gen_one "npc_default" "civilian npc, desert clothes" 52002
gen_one "npc_guard" "guard npc, light armor, helmet" 52003

echo ""
echo "Terminé → SRC=${OUTPUT} ./scripts/deploy_sprites_to_prime.sh"
