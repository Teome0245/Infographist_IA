# Lance ComfyUI (version PowerShell avec logs).
$ComfyDir = "C:\Users\sdesh\ComfyUI"
$Python   = "$ComfyDir\venv\Scripts\python.exe"
$LogFile  = "$ComfyDir\user\boot.log"

function Write-Log($msg) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

if (-not (Test-Path $Python)) {
    Write-Log "ERREUR: python introuvable ($Python)"
    exit 1
}

Set-Location $ComfyDir
Write-Log "Demarrage ComfyUI (--listen 0.0.0.0 --lowvram)"

& $Python main.py --listen 0.0.0.0 --port 8188 --lowvram 2>&1 | ForEach-Object {
    Add-Content -Path $LogFile -Value $_
}

Write-Log "ComfyUI arrete (code $LASTEXITCODE)"
