#!/usr/bin/env bash
# Installe ComfyUI en service systemd sur VM 140 (GPU worker).
# Prérequis : ComfyUI installé, venv Python, nvidia-smi OK.
#
# Variables :
#   COMFY_DIR=/opt/ComfyUI
#   COMFY_USER=lbg
set -euo pipefail

COMFY_DIR="${COMFY_DIR:-/opt/ComfyUI}"
COMFY_USER="${COMFY_USER:-lbg}"
SERVICE_NAME="comfyui-infographiste"

if [[ ! -f "${COMFY_DIR}/main.py" ]]; then
  echo "Erreur: ${COMFY_DIR}/main.py introuvable."
  echo "Installer ComfyUI d'abord sur 140."
  exit 1
fi

PYTHON="${COMFY_DIR}/venv/bin/python"
if [[ ! -x "${PYTHON}" ]]; then
  PYTHON="${COMFY_DIR}/.venv/bin/python"
fi
if [[ ! -x "${PYTHON}" ]]; then
  echo "Erreur: venv Python introuvable dans ${COMFY_DIR}"
  exit 1
fi

cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=ComfyUI Infographiste IA (GPU worker)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${COMFY_USER}
Group=${COMFY_USER}
WorkingDirectory=${COMFY_DIR}
Environment=CUDA_VISIBLE_DEVICES=0
ExecStart=${PYTHON} main.py --listen 0.0.0.0 --port 8188 --lowvram
Restart=on-failure
RestartSec=30
StandardOutput=append:${COMFY_DIR}/user/comfyui-service.log
StandardError=append:${COMFY_DIR}/user/comfyui-service.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
systemctl restart "${SERVICE_NAME}"
echo "OK: systemctl status ${SERVICE_NAME}"
systemctl --no-pager status "${SERVICE_NAME}" || true
