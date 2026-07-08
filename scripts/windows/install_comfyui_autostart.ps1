# Installe ComfyUI en demarrage automatique Windows (Planificateur de taches).
# Executer en PowerShell ADMINISTRATEUR :
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\install_comfyui_autostart.ps1
#
# Depuis WSL :
#   powershell.exe -ExecutionPolicy Bypass -File "\\wsl$\Ubuntu\home\sdesh\projects\Infographiste_IA\scripts\windows\install_comfyui_autostart.ps1"

$TaskName  = "ComfyUI-Infographiste"
$ComfyDir  = "C:\Users\sdesh\ComfyUI"
$BatchFile = "$ComfyDir\start_comfyui.bat"

# Copier le batch de lancement dans le dossier ComfyUI
$SourceBatch = Join-Path $PSScriptRoot "start_comfyui.bat"
if (-not (Test-Path $SourceBatch)) {
    Write-Error "start_comfyui.bat introuvable dans $PSScriptRoot"
    exit 1
}
Copy-Item -Force $SourceBatch $BatchFile
Write-Host "Batch copie vers $BatchFile"

# Creer le dossier de logs si besoin
$UserDir = "$ComfyDir\user"
if (-not (Test-Path $UserDir)) { New-Item -ItemType Directory -Path $UserDir | Out-Null }

# Supprimer l'ancienne tache si elle existe
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Ancienne tache supprimee."
}

# Action : lancer le batch
$action = New-ScheduledTaskAction `
    -Execute $BatchFile `
    -WorkingDirectory $ComfyDir

# Declencheur : a la connexion utilisateur, avec delai de 30s (GPU/drivers)
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$trigger.Delay = "PT30S"

# Parametres : relance en cas d'echec, ne pas arreter sur batterie
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 2) `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0)  # pas de limite

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "ComfyUI pour Infographiste IA (demarrage auto, API WSL sur :8188)" `
    -RunLevel Limited

Write-Host ""
Write-Host "Tache '$TaskName' installee."
Write-Host "  Declencheur : connexion utilisateur + 30s de delai"
Write-Host "  Logs        : $ComfyDir\user\boot.log"
Write-Host "  API         : http://127.0.0.1:8188 (Windows) / http://<IP-WSL-gateway>:8188 (WSL)"
Write-Host ""
Write-Host "Pour tester maintenant :"
Write-Host "  Start-ScheduledTask -TaskName '$TaskName'"
Write-Host ""
Write-Host "Pour desinstaller :"
Write-Host "  .\uninstall_comfyui_autostart.ps1"
