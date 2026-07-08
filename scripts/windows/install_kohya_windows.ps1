# Installe kohya_ss (sd-scripts) sur Windows pour entraînement LoRA GPU.
# Executer en PowerShell :
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\install_kohya_windows.ps1

$KohyaDir = "C:\Users\sdesh\kohya_ss"
$RepoUrl  = "https://github.com/kohya-ss/sd-scripts.git"

if (Test-Path $KohyaDir) {
    Write-Host "kohya_ss deja present: $KohyaDir"
} else {
    Write-Host "Clonage sd-scripts vers $KohyaDir ..."
    git clone $RepoUrl $KohyaDir
}

Set-Location $KohyaDir

if (-not (Test-Path "venv")) {
    Write-Host "Creation du venv kohya..."
    python -m venv venv
}

& .\venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118
pip install -r requirements.txt
pip install bitsandbytes xformers

Write-Host ""
Write-Host "OK: kohya_ss installe dans $KohyaDir"
Write-Host ""
Write-Host "Etapes suivantes (WSL):"
Write-Host "  ./scripts/mount_nas_dataset.sh"
Write-Host "  ./scripts/prepare_kohya_dataset.sh"
Write-Host "  ./scripts/train_lora_sd15.sh --name mmorpg_insp_lora --deploy"
