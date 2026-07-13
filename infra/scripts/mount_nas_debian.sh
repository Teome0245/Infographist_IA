#!/usr/bin/env bash
# Monte le NAS Infographiste_IA sur Debian (VM 110/140).
# Usage (sur la VM) : sudo bash infra/scripts/mount_nas_debian.sh
set -euo pipefail

MOUNT_POINT="${NAS_MOUNT_PATH:-/mnt/nas_lbg}"
SHARE_SUBPATH="${NAS_SHARE_SUBPATH:-LBG_Cloud_Drive/Infographiste_IA}"
# Adapter si ton export NFS/SMB diffère :
NAS_SERVER="${NAS_SERVER:-Nas_lbg}"
NAS_EXPORT="${NAS_EXPORT:-/nas}"

mkdir -p "${MOUNT_POINT}"

if mountpoint -q "${MOUNT_POINT}" 2>/dev/null; then
  echo "Déjà monté : ${MOUNT_POINT}"
else
  # Option A : CIFS (SMB) — le plus courant avec Nas_lbg Windows/Samba
  if command -v mount.cifs &>/dev/null; then
  CRED_FILE="${CRED_FILE:-/etc/samba/credentials-nas}"
  if [[ ! -f "${CRED_FILE}" ]]; then
    echo "Créer ${CRED_FILE} (username=... password=...) puis relancer."
    echo "Exemple :"
    echo "  sudo mkdir -p /etc/samba"
    echo "  sudo nano /etc/samba/credentials-nas"
    exit 1
  fi
  mount -t cifs "//${NAS_SERVER}${NAS_EXPORT}" "${MOUNT_POINT}" \
    -o "credentials=${CRED_FILE},uid=$(id -u lbg 2>/dev/null || echo 1000),gid=$(id -g lbg 2>/dev/null || echo 1000),file_mode=0664,dir_mode=0775"
  else
    echo "Installer cifs-utils : sudo apt install cifs-utils"
    exit 1
  fi
fi

DATA_DIR="${MOUNT_POINT}/Infographiste_IA"
mkdir -p "${DATA_DIR}"/{dataset,lora,assets/images,exports_3d,logs,kohya_train}
echo "OK: ${DATA_DIR}"
