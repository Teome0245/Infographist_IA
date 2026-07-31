#!/usr/bin/env bash
# Copie les portraits générés vers Prime Client et met à jour dialogue_portraits.json.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC="${SRC:-${PROJECT_DIR}/pipelines/portraits/outputs/mvp}"
PRIME_ROOT="${PRIME_ROOT:-/home/sdesh/projects/new_mmo/prime-client}"
PORTRAITS_DIR="${PRIME_ROOT}/assets/ui/portraits"
MANIFEST="${PRIME_ROOT}/config/dialogue_portraits.json"

if [[ ! -d "${SRC}" ]]; then
  echo "Source absente : ${SRC}"
  echo "Lancez d'abord : python scripts/run_dialogue_portrait_batch.py"
  exit 1
fi

mkdir -p "${PORTRAITS_DIR}"

copied=0
while IFS= read -r -d '' png; do
  rel="${png#${SRC}/}"
  char_id="${rel%%/*}"
  base="$(basename "${png}" .png)"
  dest_dir="${PORTRAITS_DIR}/${char_id}"
  mkdir -p "${dest_dir}"
  cp -f "${png}" "${dest_dir}/${base}.png"
  echo "→ ${dest_dir}/${base}.png"
  copied=$((copied + 1))
done < <(find "${SRC}" -mindepth 2 -maxdepth 2 -name '*.png' -print0)

if [[ "${copied}" -eq 0 ]]; then
  echo "Aucun PNG trouvé sous ${SRC}/<character>/*.png"
  exit 1
fi

python3 - <<'PY' "${MANIFEST}" "${PORTRAITS_DIR}"
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
portraits_dir = Path(sys.argv[2])
data = json.loads(manifest_path.read_text(encoding="utf-8"))
portraits = data.setdefault("portraits", {})
updated = 0
for char_dir in sorted(portraits_dir.iterdir()):
    if not char_dir.is_dir():
        continue
    char_id = char_dir.name
    for png in sorted(char_dir.glob("*.png")):
        key = f"{char_id}_{png.stem}"
        res_path = f"res://assets/ui/portraits/{char_id}/{png.name}"
        if portraits.get(key) != res_path:
            portraits[key] = res_path
            updated += 1
manifest_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Manifest mis à jour : {updated} entrée(s) → {manifest_path}")
PY

echo "Déploiement terminé (${copied} fichier(s))."
