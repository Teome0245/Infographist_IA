#!/usr/bin/env bash
# Génère des prompts de portraits dialogue pour un personnage donné.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CHAR_ID="${1:-}"
CHAR_DESC="${2:-fantasy sci-fi mmorpg character}"
OUT_DIR="${3:-${PROJECT_DIR}/tmp/dialogue_portraits}"

if [[ -z "${CHAR_ID}" ]]; then
  echo "Usage: $0 <character_id> [character_description] [output_dir]"
  exit 1
fi

BASE_PROMPT="$(cat "${PROJECT_DIR}/pipelines/portraits/prompts/portrait_base.txt")"
mkdir -p "${OUT_DIR}/${CHAR_ID}"

python3 - <<PY
import json
from pathlib import Path

base = ${BASE_PROMPT@Q}
char_id = ${CHAR_ID@Q}
char_desc = ${CHAR_DESC@Q}
out_dir = Path(${OUT_DIR@Q}) / char_id
exprs = json.loads(Path(${PROJECT_DIR@Q} + "/pipelines/portraits/prompts/expressions.json").read_text())

for expression, suffix in exprs.items():
    prompt = f"{base}, {char_desc}, {suffix}"
    (out_dir / f"{expression}.prompt.txt").write_text(prompt + "\\n", encoding="utf-8")

print(f"Prompts générés dans {out_dir}")
PY

echo "Étape suivante : utiliser ces prompts avec le workflow portrait ComfyUI."
