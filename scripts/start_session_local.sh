#!/usr/bin/env bash
# Prépare une session de travail LOCAL (PC GPU, VMs sans rendu).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

# Profil LOCAL si pas de .env
if [[ ! -f .env ]]; then
  cp config/.env.local.example .env
  sed -i 's/\r$//' .env
  echo "Créé .env depuis config/.env.local.example"
fi

./scripts/setup_data_drive.sh
./scripts/mount_nas_dataset.sh 2>/dev/null || echo "NAS: skip (optionnel)"

if [[ ! -d .venv ]]; then
  ./scripts/bootstrap_venv.sh
fi

source .venv/bin/activate
./scripts/verify_local.sh
