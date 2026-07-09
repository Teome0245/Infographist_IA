# Entraînement LoRA SD1.5 — dataset NAS inspiration MMORPG

Objectif : entraîner un LoRA sur tes **1588 images** d'inspiration (`dataset/inspiration_mmorpg`) pour le style MMORPG, compatible **GTX 1050 Ti 4 Go**.

## Prérequis

- ComfyUI + `DreamShaper_8_pruned.safetensors` (SD1.5)
- **kohya_ss** (sd-scripts) sur Windows
- NAS monté dans WSL

## Stockage (B: — pas de saturation C:)

Par défaut tout est sur **`B:\Infographiste_IA\`** :

| Dossier | Contenu |
|---------|---------|
| `B:\Infographiste_IA\kohya_train\` | Dataset d'entraînement (copies) |
| `B:\Infographiste_IA\lora\` | LoRA entraînés |
| `B:\Infographiste_IA\assets\images\` | Images générées |
| `B:\Infographiste_IA\logs\` | Logs d'entraînement |

```bash
./scripts/setup_data_drive.sh    # une fois, crée l'arborescence + symlinks
```

Variables dans `.env` : `DATA_ROOT`, `DATA_ROOT_WIN`, `ASSETS_DIR`, `KOHYA_TRAIN_DIR`.

## Pipeline complet

### 1. Monter le NAS (WSL)

```bash
cd ~/projects/Infographiste_IA
./scripts/mount_nas_dataset.sh
./scripts/setup_data_drive.sh
```

### 2. Installer kohya_ss (Windows, une fois)

Déjà installé dans `C:\Users\sdesh\kohya_ss` (code seulement — léger sur C:).

### 3. Préparer le dataset (200 images → B:)

```bash
source .venv/bin/activate
MAX_IMAGES=200 ./scripts/prepare_kohya_dataset_windows.sh
# Dataset complet plus tard : MAX_IMAGES= ./scripts/prepare_kohya_dataset_windows.sh
```

### 4. Entraîner le LoRA

```bash
./scripts/train_lora_sd15.sh --name mmorpg_insp_lora --deploy
```

Durée estimée 200 images × 3 repeats × 3 epochs ≈ **~8 h** (1050 Ti).

### 5. Générer

```bash
python orchestrator.py generate \
  --workflow workflows/workflow_sd15_lora_lowvram.json \
  --prompt "mmorpg_insp, paysage fantasy brumeux, ruines anciennes" \
  --lora "mmorpg_insp_lora.safetensors"
```

Images dans `B:\Infographiste_IA\assets\images\`.

## Test rapide (10 images)

```bash
MAX_IMAGES=10 ./scripts/prepare_kohya_dataset_windows.sh
./scripts/train_lora_sd15.sh --name mmorpg_test_10 --epochs 2 --deploy
```

## Dépannage

| Problème | Solution |
|----------|----------|
| CUDA OOM | Réduire `--network-dim 8` ou `MAX_IMAGES=200` |
| kohya absent | `install_kohya_windows.ps1` |
| Dataset vide | `mount_nas_dataset.sh` puis `prepare_kohya_dataset.sh` |
| LoRA introuvable dans ComfyUI | Vérifier `C:\Users\sdesh\ComfyUI\models\loras\` |
