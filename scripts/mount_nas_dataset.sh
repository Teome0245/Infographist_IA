#!/usr/bin/env bash
# Monte le NAS LBG dans WSL pour accéder au dataset d'inspiration MMORPG.
set -euo pipefail

MOUNT_POINT="/mnt/nas_lbg/nas"
UNC_SOURCE='\\Nas_lbg\nas'

if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
  echo "NAS déjà monté sur $MOUNT_POINT"
  exit 0
fi

sudo mkdir -p "$MOUNT_POINT"
sudo mount -t drvfs "$UNC_SOURCE" "$MOUNT_POINT"
echo "NAS monté : $MOUNT_POINT"

INSPIRATION="/mnt/nas_lbg/nas/LBG_Cloud_Drive/OneDrive - sdesharches/Photos/0 - A trier/Pictures/Inspiration pour MMORPG"
if [[ -d "$INSPIRATION" ]]; then
  COUNT=$(find "$INSPIRATION" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | wc -l)
  echo "Dataset inspiration : $INSPIRATION ($COUNT images)"
else
  echo "Attention: dossier inspiration introuvable."
fi
