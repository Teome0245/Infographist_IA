# Entraînement LoRA SD1.5 — dataset NAS inspiration MMORPG

Objectif : entraîner un LoRA sur tes **1588 images** d'inspiration (`dataset/inspiration_mmorpg`) pour le style MMORPG, compatible **GTX 1050 Ti 4 Go**.

## Prérequis

- ComfyUI + `DreamShaper_8_pruned.safetensors` (SD1.5)
- **kohya_ss** (sd-scripts) sur Windows
- NAS monté dans WSL

## Pipeline complet

### 1. Monter le NAS (WSL)

```bash
cd ~/projects/Infographiste_IA
./scripts/mount_nas_dataset.sh
```

### 2. Installer kohya_ss (Windows, une fois)

```powershell
cd \\wsl$\Ubuntu\home\sdesh\projects\Infographiste_IA\scripts\windows
Set-ExecutionPolicy -Scope Process Bypass
.\install_kohya_windows.ps1
```

### 3. Préparer le dataset Kohya (WSL)

```bash
source .venv/bin/activate
./scripts/prepare_kohya_dataset.sh
# ou avec limite pour test rapide :
# MAX_IMAGES=50 ./scripts/prepare_kohya_dataset.sh
```

Crée `dataset/kohya_train/10_mmorpg_insp/` avec :
- symlinks vers les images NAS
- captions `.txt` avec le trigger word `mmorpg_insp`

### 4. Entraîner le LoRA

**Option A — depuis WSL** (via kohya Windows) :

```bash
./scripts/train_lora_sd15.sh --name mmorpg_insp_lora --deploy
```

**Option B — PowerShell Windows** (recommandé, GPU direct) :

```powershell
.\train_lora_sd15.ps1 -Name mmorpg_insp_lora -Deploy
```

Paramètres adaptés 4 Go VRAM :
| Paramètre | Valeur |
|-----------|--------|
| Résolution | 512 |
| network_dim | 16 |
| batch_size | 1 |
| mixed_precision | fp16 |
| optimizer | AdamW8bit |
| cache_latents | oui |
| gradient_checkpointing | oui |

Durée estimée : **2–6 h** pour 1588 images × 10 repeats, 5 epochs (1050 Ti).

### 5. Générer avec le LoRA

```bash
python orchestrator.py generate \
  --workflow workflows/workflow_sd15_lora_lowvram.json \
  --prompt "mmorpg_insp, paysage fantasy brumeux, ruines anciennes, sunrise" \
  --lora "mmorpg_insp_lora.safetensors"
```

Le trigger word `mmorpg_insp` active le style appris.

## Test rapide (50 images)

```bash
MAX_IMAGES=50 ./scripts/prepare_kohya_dataset.sh
./scripts/train_lora_sd15.sh --name mmorpg_test --epochs 2 --deploy
```

## Dépannage

| Problème | Solution |
|----------|----------|
| CUDA OOM | Réduire `--network-dim 8` ou `MAX_IMAGES=200` |
| kohya absent | `install_kohya_windows.ps1` |
| Dataset vide | `mount_nas_dataset.sh` puis `prepare_kohya_dataset.sh` |
| LoRA introuvable dans ComfyUI | Vérifier `C:\Users\sdesh\ComfyUI\models\loras\` |
