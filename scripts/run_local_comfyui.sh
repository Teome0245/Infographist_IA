#!/usr/bin/env bash
set -euo pipefail

COMFY_DIR="${1:-}"
if [[ -z "${COMFY_DIR}" ]]; then
  echo "Usage: $0 /chemin/vers/ComfyUI"
  exit 1
fi

if [[ ! -f "${COMFY_DIR}/main.py" ]]; then
  echo "Erreur: ${COMFY_DIR} ne contient pas main.py (ComfyUI)."
  exit 1
fi

cd "${COMFY_DIR}"

# --listen : expose l'API (127.0.0.1 par défaut si --listen 127.0.0.1)
# --port 8188 : port standard ComfyUI
python3 main.py --listen 0.0.0.0 --port 8188

