# Mode LOCAL — PC Windows (GPU) + VMs sans rendu

Configuration active : **tout le rendu IA sur le PC**, les VMs **110/140** servent au stockage NAS et au LLM uniquement.

## Architecture

```
[PC Windows — GTX 1050 Ti]          [VMs 110/140 — CPU only]
ComfyUI :8188  ◄── WSL orchestrator   110 : Ollama (LLM)
kohya (entraînement LoRA)             NAS sync (optionnel)
Stockage B:\Infographiste_IA          Pas de ComfyUI
```

## Démarrage session

```bash
cd ~/projects/Infographiste_IA
./scripts/start_session_local.sh
```

Ou manuellement :

```bash
cp config/.env.local.example .env   # si premier lancement
./scripts/setup_data_drive.sh       # monte B:
./scripts/mount_nas_dataset.sh      # optionnel — dataset NAS
source .venv/bin/activate
./scripts/verify_local.sh
```

## ComfyUI (Windows — à lancer à chaque boot)

```powershell
cd C:\Users\sdesh\ComfyUI
.\venv\Scripts\Activate.ps1
python main.py --listen 0.0.0.0 --port 8188 --lowvram
```

Ou tâche planifiée : `scripts/windows/install_comfyui_autostart.ps1`

## Génération (WSL)

```bash
python orchestrator.py generate \
  --workflow workflows/workflow_sd15_lora_refined.json \
  --prompt "mmorpg_insp, small floating steampunk drone, brass body, sharp focus" \
  --lora mmorpg_insp_lora.safetensors \
  --seed 42
```

Sortie : `B:\Infographiste_IA\assets\images\`

## Entraînement LoRA (PC uniquement)

```bash
MAX_IMAGES=200 ./scripts/prepare_kohya_dataset_windows.sh
./scripts/train_lora_sd15.sh --name mmorpg_insp_lora --deploy
```

## VMs — ce qu'on n'y fait PAS (pour l'instant)

- Pas de ComfyUI sur 110/140
- Pas d'entraînement LoRA sur 110/140
- Pas de `INFRA_MODE=DISTRIBUTED` tant qu'il n'y a pas de GPU sur une VM

Voir `docs/INFRA_LAN.md` pour la bascule future quand un GPU sera sur 140.

## Bascule explicite

```bash
./scripts/switch_infra.sh local      # PC GPU (défaut)
./scripts/switch_infra.sh status
```
