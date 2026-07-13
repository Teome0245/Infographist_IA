# Infographiste virtuel (ComfyUI + FLUX.1/SDXL) — MMORPG

Objectif : automatiser la génération d'assets (paysages, concepts) via l'API de ComfyUI à partir d'un dossier `dataset/` (références pour LoRA), avec deux modes d'exécution interchangeables :

- **LOCAL** : ComfyUI sur **PC Windows** (GTX 1050 Ti) — **mode actif**
- **DISTRIBUTED** : réservé quand une VM (140) aura un GPU — VMs 110/140 = NAS + LLM seulement pour l'instant

> **Mode actuel** : voir `docs/MODE_LOCAL.md` — `./scripts/start_session_local.sh`

## Structure

```
.
├─ assets/
│  └─ images/
├─ config/
│  ├─ config.yaml
│  └─ .env.example
├─ dataset/
│  └─ README.md
├─ docs/
│  └─ DISTRIBUTED.md
├─ scripts/
│  ├─ bootstrap_venv.sh
│  ├─ run_local_comfyui.sh
│  ├─ train_lora_local.sh
│  └─ upload_to_s3.sh
├─ src/
│  └─ infographiste_virtuel/
│     ├─ __init__.py
│     ├─ comfy_client.py
│     ├─ config.py
│     ├─ dataset.py
│     ├─ storage.py
│     └─ workflow_patch.py
├─ workflows/
│  └─ README.md
├─ orchestrator.py
└─ requirements.txt
```

## Prérequis

- Python 3.10+
- ComfyUI installé et fonctionnel (FLUX.1 dev / SDXL selon ton setup)
- (Optionnel) `awscli` + un bucket S3 pour le mode distribué

## Installation rapide

```bash
cd Infographiste_IA
./scripts/start_session_local.sh
# ou : cp config/.env.local.example .env && ./scripts/bootstrap_venv.sh
```

## Mode LOCAL (ComfyUI sur `localhost:8188`)

> **Setup WSL + Windows** : voir `docs/LOCAL_WSL_WINDOWS.md`  
> **Démarrage auto Windows** : `scripts/windows/install_comfyui_autostart.ps1`

1) Lance ComfyUI avec l'API ouverte :

```bash
./scripts/run_local_comfyui.sh /chemin/vers/ComfyUI
```

2) Exporte un workflow JSON depuis l'UI ComfyUI et place-le dans `workflows/` (voir `workflows/README.md`).

3) Exécute l’orchestrateur :

```bash
# Scanner le dataset
python orchestrator.py scan

# Générer un asset
python orchestrator.py generate \
  --workflow workflows/workflow.json \
  --prompt "Paysage fantasy brumeux, ruines anciennes, sunrise, ultra-detailed" \
  --lora "my_lora.safetensors"
```

Les images sont sauvegardées dans `assets/images/`.

## Entraînement LoRA (dataset NAS)

Voir `docs/TRAIN_LORA.md` pour le pipeline complet.

```bash
./scripts/mount_nas_dataset.sh
./scripts/prepare_kohya_dataset.sh
./scripts/train_lora_sd15.sh --name mmorpg_insp_lora --deploy
```

## Mode DISTRIBUTED (Infra 110/140)

Voir `docs/DISTRIBUTED.md` pour la mise en place (endpoint API, stockage distant, timeouts).
