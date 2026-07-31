# AGENTS.md

**Infographiste virtuel** — orchestrateur Python (CLI) pour générer des assets via l'API **ComfyUI** (FLUX.1 / SDXL) à partir d'un dossier `dataset/`, avec deux modes : `LOCAL` (ComfyUI `:8188`) et `DISTRIBUTED` (endpoints distants + S3). Détail : `README.md`.

## Cursor Cloud specific instructions

- **Installation** : `./scripts/bootstrap_venv.sh` (crée `.venv` et installe `requirements.txt` : requests, PyYAML, python-dotenv, tenacity, boto3). Équivalent manuel : `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt`.
- **Config** : `cp config/.env.example .env` si besoin (mode/endpoints). Défauts dans `src/infographiste_virtuel/config.py`.
- **Vérif rapide (hello-world)** : `.venv/bin/python orchestrator.py scan --dataset-dir <dir>` — scanne récursivement un dossier et compte images + captions (`.txt` associés). Le scan détecte par **extension** (`.png/.jpg/.jpeg/.webp/.bmp/.tif`), sans lire le contenu ; un dossier de fichiers vides aux bonnes extensions suffit pour tester le pipeline de scan.
- **Limite environnement** : la commande `generate` nécessite une instance **ComfyUI + GPU** (`:8188`), indisponible dans le cloud VM → non exerçable ici. De même, l'entraînement LoRA et le mode DISTRIBUTED (S3) requièrent une infra externe.
- Pas de tests automatisés ni de linter dans ce dépôt.
