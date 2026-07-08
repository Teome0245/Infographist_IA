# Ouvre le port 8188 dans le pare-feu Windows (acces WSL -> ComfyUI).
# Executer en PowerShell ADMINISTRATEUR.

$RuleName = "ComfyUI-WSL-8188"

$existing = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Regle '$RuleName' deja presente."
    exit 0
}

New-NetFirewallRule `
    -DisplayName $RuleName `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 8188 `
    -Action Allow `
    -Profile Private,Domain `
    -Description "Autorise WSL a acceder a ComfyUI sur le port 8188"

Write-Host "Regle pare-feu '$RuleName' creee (port 8188 TCP entrant)."
