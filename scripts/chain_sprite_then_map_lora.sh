#!/usr/bin/env bash
# Attend la fin de prime_sprite_2d_lora, déploie, puis entraîne map_topdown_lora.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="/mnt/c/Users/sdesh/Infographiste_IA_data"
COMFY_LORA="/mnt/c/Users/sdesh/ComfyUI/models/loras"
LOG="${PROJECT_DIR}/logs/chain_sprite_then_map.log"
SPRITE_OUT="${DATA}/lora/prime_sprite_2d_lora.safetensors"
MAP_OUT="${DATA}/lora/map_topdown_lora.safetensors"
DETECT='C:\Users\sdesh\Infographiste_IA_data\detect_train.ps1'
LAUNCH='C:\Users\sdesh\Infographiste_IA_data\launch_train_detached.ps1'
MAP_DIR='C:\Users\sdesh\Infographiste_IA_data\kohya_train_by_style\_single_map_topdown'
ERR_LOG="${DATA}/logs/train_prime_sprite_2d_lora.log.err"

mkdir -p "${PROJECT_DIR}/logs" "${COMFY_LORA}"
# Ne pas écraser le log à chaque poll : append seulement via log()
log() { echo "[$(date -Iseconds)] $*" >> "${LOG}"; echo "[$(date -Iseconds)] $*"; }

train_count() {
  local key="$1" # COUNT|SPRITE|MAP
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${DETECT}" 2>/dev/null \
    | tr -d '\r' | awk -F= -v k="$key" '$1==k{print $2; found=1} END{if(!found) print 0}'
}

log_recently_updated() {
  local f="$1" max_age="$2"
  [[ -f "$f" ]] || return 1
  local now mtime age
  now=$(date +%s)
  mtime=$(stat -c %Y "$f" 2>/dev/null || echo 0)
  age=$((now - mtime))
  [[ "$age" -lt "$max_age" ]]
}

log "=== Chaîne LoRA sprite → map démarrée ==="
log "Attente fin prime_sprite_2d_lora…"

stable_gone=0
while true; do
  sc=$(train_count SPRITE)
  tc=$(train_count COUNT)
  active=0
  if [[ "${sc}" -gt 0 || "${tc}" -gt 0 ]]; then active=1; fi
  if log_recently_updated "${ERR_LOG}" 300; then active=1; fi

  step="$(tr '\r' '\n' < "${ERR_LOG}" 2>/dev/null | grep 'steps:' | tail -1 || true)"

  if [[ "${active}" -eq 1 ]]; then
    stable_gone=0
    log "Train actif (SPRITE=${sc} COUNT=${tc}). ${step:0:120}"
  else
    if [[ -f "${SPRITE_OUT}" ]]; then
      stable_gone=$((stable_gone + 1))
      log "Train arrêté + LoRA présent (confirmation ${stable_gone}/3)"
      [[ "${stable_gone}" -ge 3 ]] && break
    else
      stable_gone=0
      log "Pas de train / pas encore de LoRA sprite. ${step:0:80}"
    fi
  fi
  sleep 180
done

log "Sprite LoRA prêt: ${SPRITE_OUT} ($(du -h "${SPRITE_OUT}" | cut -f1))"
cp -f "${SPRITE_OUT}" "${COMFY_LORA}/prime_sprite_2d_lora.safetensors"
shopt -s nullglob
for f in "${DATA}/lora"/prime_sprite_2d_lora-*.safetensors; do
  cp -f "$f" "${COMFY_LORA}/"; log "Deployed $(basename "$f")"
done
shopt -u nullglob

MAP_WSL="${DATA}/kohya_train_by_style/_single_map_topdown/12_lbg_map2d"
IMG_COUNT=$(find "${MAP_WSL}" -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | wc -l)
log "Dataset map: ${IMG_COUNT} images"
[[ "${IMG_COUNT}" -ge 10 ]] || { log "ERREUR dataset map"; exit 1; }

if [[ -f "${MAP_OUT}" ]]; then
  log "map_topdown_lora déjà présent — deploy only"
  cp -f "${MAP_OUT}" "${COMFY_LORA}/map_topdown_lora.safetensors"
  exit 0
fi

tc=$(train_count COUNT)
if [[ "${tc}" -gt 0 ]]; then
  log "ERREUR: train encore actif (COUNT=${tc}), pas de lancement map"
  exit 1
fi

log "Lancement map_topdown_lora…"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${LAUNCH}" \
  -StyleDir "${MAP_DIR}" -OutputName 'map_topdown_lora' -Epochs 3 >> "${LOG}" 2>&1

# Attendre fin du train map
stable_gone=0
MAP_ERR="${DATA}/logs/train_map_topdown_lora.log.err"
while true; do
  mc=$(train_count MAP)
  tc=$(train_count COUNT)
  if [[ "${mc}" -gt 0 || "${tc}" -gt 0 ]] || log_recently_updated "${MAP_ERR}" 300; then
    stable_gone=0
    step="$(tr '\r' '\n' < "${MAP_ERR}" 2>/dev/null | grep 'steps:' | tail -1 || true)"
    log "Map train actif. ${step:0:120}"
  else
    if [[ -f "${MAP_OUT}" ]]; then
      stable_gone=$((stable_gone + 1))
      log "Map LoRA présent (confirmation ${stable_gone}/3)"
      [[ "${stable_gone}" -ge 3 ]] && break
    else
      stable_gone=0
      log "Map train terminé sans LoRA encore…"
    fi
  fi
  sleep 120
done

cp -f "${MAP_OUT}" "${COMFY_LORA}/map_topdown_lora.safetensors"
shopt -s nullglob
for f in "${DATA}/lora"/map_topdown_lora-*.safetensors; do cp -f "$f" "${COMFY_LORA}/"; done
shopt -u nullglob
log "OK: map_topdown_lora déployé ($(du -h "${MAP_OUT}" | cut -f1))"
log "=== Chaîne terminée ==="
