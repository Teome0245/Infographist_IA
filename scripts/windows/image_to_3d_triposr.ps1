# TripoSR : image -> mesh.glb (Windows GPU)
param(
    [string]$InputImage = "B:\Infographiste_IA\pipelines\3d\outputs\multiview\robot01_round\robot01_round_back.png",
    [string]$OutputDir = "B:\Infographiste_IA\pipelines\3d\outputs\mesh\robot01_round",
    [string]$TripoDir = "C:\Users\sdesh\TripoSR",
    [string]$Python = "C:\Users\sdesh\ComfyUI\venv\Scripts\python.exe"
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OutputDir "0") | Out-Null

Set-Location $TripoDir

Write-Host "=== TripoSR image->3D ==="
Write-Host "Input:  $InputImage"
Write-Host "Output: $OutputDir"

& $Python run.py $InputImage `
  --output-dir $OutputDir `
  --chunk-size 2048 `
  --mc-resolution 128 `
  --model-save-format glb `
  --bake-texture `
  --texture-resolution 1024 `
  --no-remove-bg

$meshRaw = Join-Path $OutputDir "0\mesh.glb"
$texture = Join-Path $OutputDir "0\texture.png"
$meshPacked = Join-Path $OutputDir "0\mesh_packed.glb"
$meshGodot = Join-Path $OutputDir "robot01_round_godot.glb"

if (-not (Test-Path $meshRaw)) {
    Write-Error "mesh introuvable: $meshRaw"
}

$Pack = "B:\Infographiste_IA\pipelines\3d\tools\pack_glb.py"
$Simplify = "B:\Infographiste_IA\pipelines\3d\tools\simplify_mesh.py"

if (Test-Path $Pack) {
    & $Python $Pack --obj $meshRaw --texture $texture --output $meshPacked
    $meshForGodot = $meshPacked
} else {
    $meshForGodot = $meshRaw
}

if (Test-Path $Simplify) {
    & $Python $Simplify --input $meshForGodot --output $meshGodot --target-tris 8000
} else {
    Copy-Item $meshForGodot $meshGodot -Force
}

Write-Host "OK: $meshGodot"
Get-Item $meshGodot | Format-List Name, Length, LastWriteTime
