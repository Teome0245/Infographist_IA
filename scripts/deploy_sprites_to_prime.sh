#!/usr/bin/env bash
# Prépare et copie les sprites 2D vers Prime Client.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC="${SRC:-${PROJECT_DIR}/pipelines/2d/outputs/units}"
STAGING="${STAGING:-${PROJECT_DIR}/pipelines/2d/staging/prime_units}"
PRIME_SPRITES="${PRIME_SPRITES:-/home/sdesh/projects/new_mmo/prime-client/assets/sprites/units}"
B_OVERHEAD="${B_OVERHEAD:-/mnt/b/Infographiste_IA/pipelines/2d/outputs/units_overhead}"
B_UNITS="${B_UNITS:-/mnt/b/Infographiste_IA/pipelines/2d/outputs/units}"
PYTHON="${PYTHON:-/mnt/c/Users/sdesh/ComfyUI/venv/Scripts/python.exe}"
PREPARE="${PROJECT_DIR}/pipelines/2d/tools/prepare_sprite.py"

mkdir -p "${PRIME_SPRITES}" "${STAGING}"

deploy_one() {
  local name="$1"
  local src="${SRC}/${name}.png"
  local staging="${STAGING}/${name}.png"
  local dst="${PRIME_SPRITES}/${name}.png"
  if [[ ! -f "${src}" ]]; then
    echo "SKIP ${name} — absent (${src})"
    return 0
  fi
  "${PYTHON}" "${PREPARE}" --input "${src}" --output "${staging}" --size 128 --remove-bg
  cp -f "${staging}" "${dst}"
  echo "→ ${dst}"
}

for sprite in player_lia player_nix player_mira player_teome player_gally player_kael \
  player_bot npc_default npc_guard player_official; do
  deploy_one "${sprite}"
done

echo ""
echo "Sprites Prime Client : ${PRIME_SPRITES}"
ls -la "${PRIME_SPRITES}/" 2>/dev/null || true

# Sync Windows client si monté
if [[ -d /mnt/j/swgemu/clients/prime-client/assets/sprites/units ]]; then
  rsync -av "${PRIME_SPRITES}/" /mnt/j/swgemu/clients/prime-client/assets/sprites/units/
  echo "→ sync J: prime-client/assets/sprites/units"
fi

if [[ -d "${B_UNITS}" ]]; then
  rsync -av "${PRIME_SPRITES}/" "${B_UNITS}/"
  echo "→ sync B: outputs/units (sprites préparés)"
fi
if [[ -d "$(dirname "${B_OVERHEAD}")" ]]; then
  mkdir -p "${B_OVERHEAD}"
  if [[ "${SRC}" == *overhead* ]] || [[ -d "${PROJECT_DIR}/pipelines/2d/outputs/units_overhead" ]]; then
    rsync -av "${SRC}/"*.png "${B_OVERHEAD}/" 2>/dev/null || true
    echo "→ copie PNG bruts B: outputs/units_overhead"
  fi
fi
