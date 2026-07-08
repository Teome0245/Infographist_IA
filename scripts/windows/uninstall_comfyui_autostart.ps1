# Desinstalle la tache planifiee ComfyUI.
$TaskName = "ComfyUI-Infographiste"

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Tache '$TaskName' supprimee."
} else {
    Write-Host "Tache '$TaskName' introuvable."
}
