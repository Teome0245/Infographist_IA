#!/usr/bin/env bash
# Initialise le stockage Infographiste_IA sur B: (évite de saturer C:).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# WSL mount point (drvfs monte B: automatiquement)
DATA_ROOT="${DATA_ROOT:-/mnt/b/Infographiste_IA}"

# Monter B: si absent (après reboot WSL)
if ! mountpoint -q /mnt/b 2>/dev/null; then
  sudo mkdir -p /mnt/b
  sudo mount -t drvfs B: /mnt/b
  echo "B: monté sur /mnt/b"
fi

mkdir -p "${DATA_ROOT}"/{kohya_train,lora,assets/images,logs}

# Symlinks dans le projet → B:
cd "${PROJECT_DIR}"
ln -sfn "${DATA_ROOT}/assets/images" assets/images
ln -sfn "${DATA_ROOT}/lora" lora

echo "Stockage Infographiste_IA : ${DATA_ROOT}"
echo "  kohya_train/   → dataset d'entraînement (copies)"
echo "  lora/          → LoRA entraînés"
echo "  assets/images/ → images générées"
echo "  logs/          → logs d'entraînement"
echo ""
echo "Espace libre sur B:"
df -h /mnt/b 2>/dev/null | tail -1 || powershell.exe -Command "(Get-PSDrive B).Free / 1GB"
