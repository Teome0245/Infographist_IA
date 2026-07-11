#!/usr/bin/env bash
# Lance TripoSR via PowerShell (évite chemins UNC cmd.exe).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PS1="${PROJECT_DIR}/scripts/windows/image_to_3d_triposr.ps1"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "${PS1}")" 2>&1 | tee /mnt/b/Infographiste_IA/pipelines/3d/outputs/mesh/robot01_round/triposr.log
