# Entraînement LoRA SD1.5 depuis Windows (GPU direct).
# Alternative si l'entraînement via WSL/mnt/c est trop lent.
param(
    [string]$Name = "mmorpg_insp_lora",
    [int]$Epochs = 5,
    [int]$NetworkDim = 16,
    [switch]$Deploy
)

$KohyaDir    = "C:\Users\sdesh\kohya_ss"
$DatasetDir  = "\\wsl$\Ubuntu\home\sdesh\projects\Infographiste_IA\dataset\kohya_train"
$OutDir      = "\\wsl$\Ubuntu\home\sdesh\projects\Infographiste_IA\lora"
$BaseModel   = "C:\Users\sdesh\ComfyUI\models\checkpoints\DreamShaper_8_pruned.safetensors"
$ComfyLoraDir = "C:\Users\sdesh\ComfyUI\models\loras"

if (-not (Test-Path $KohyaDir)) {
    Write-Error "kohya_ss absent. Lance install_kohya_windows.ps1 d'abord."
    exit 1
}
if (-not (Test-Path $DatasetDir)) {
    Write-Error "Dataset Kohya absent. Lance prepare_kohya_dataset.sh depuis WSL."
    exit 1
}

Set-Location $KohyaDir
& .\venv\Scripts\Activate.ps1

python train_network.py `
  --pretrained_model_name_or_path $BaseModel `
  --train_data_dir $DatasetDir `
  --output_dir $OutDir `
  --output_name $Name `
  --save_model_as safetensors `
  --network_module networks.lora `
  --network_dim $NetworkDim `
  --network_alpha $NetworkDim `
  --learning_rate 1e-4 `
  --unet_lr 1e-4 `
  --text_encoder_lr 5e-5 `
  --optimizer_type AdamW8bit `
  --lr_scheduler cosine `
  --lr_warmup_steps 100 `
  --train_batch_size 1 `
  --max_train_epochs $Epochs `
  --save_every_n_epochs 1 `
  --mixed_precision fp16 `
  --save_precision fp16 `
  --cache_latents `
  --gradient_checkpointing `
  --xformers `
  --resolution 512 `
  --enable_bucket `
  --min_bucket_reso 256 `
  --max_bucket_reso 512 `
  --bucket_reso_steps 64 `
  --caption_extension .txt `
  --shuffle_caption `
  --keep_tokens 1 `
  --seed 42

$LoraFile = Join-Path $OutDir "$Name.safetensors"
Write-Host "OK: $LoraFile"

if ($Deploy) {
    Copy-Item $LoraFile $ComfyLoraDir -Force
    Write-Host "Deploye vers $ComfyLoraDir"
}
