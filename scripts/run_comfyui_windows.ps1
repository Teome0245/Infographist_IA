# Lance ComfyUI sur Windows, accessible depuis WSL (Infographiste_IA).
#
# Usage (PowerShell) :
#   cd C:\Users\sdesh\ComfyUI
#   .\scripts\run_comfyui_windows.ps1
#
# Ou depuis ce repo (chemin WSL monté) :
#   powershell.exe -File \\wsl$\Ubuntu\home\sdesh\projects\Infographiste_IA\scripts\run_comfyui_windows.ps1

$ComfyDir = "C:\Users\sdesh\ComfyUI"

if (-not (Test-Path "$ComfyDir\main.py")) {
    Write-Error "ComfyUI introuvable dans $ComfyDir"
    exit 1
}

Set-Location $ComfyDir
& .\venv\Scripts\Activate.ps1

# --listen 0.0.0.0 : expose l'API vers WSL (sinon localhost Windows uniquement)
# --lowvram        : ton profil GPU actuel
python main.py --listen 0.0.0.0 --port 8188 --lowvram
