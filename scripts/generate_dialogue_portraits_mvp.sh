#!/usr/bin/env bash
# Prépare puis génère le lot MVP de portraits dialogue (ComfyUI requis).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"
if [[ -f .venv/bin/activate ]]; then
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi

CHAR_FILTER="${1:-}"
PREPARE=(python3 scripts/prepare_dialogue_portrait_batch.py)
RUN=(python3 scripts/run_dialogue_portrait_batch.py)

"${PREPARE[@]}"

if [[ -n "${CHAR_FILTER}" ]]; then
  "${RUN[@]}" --character "${CHAR_FILTER}"
else
  "${RUN[@]}"
fi

echo ""
echo "Déploiement Prime Client :"
"${SCRIPT_DIR}/deploy_dialogue_portraits_to_prime.sh"
