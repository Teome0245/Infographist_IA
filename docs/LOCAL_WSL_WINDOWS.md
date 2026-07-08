# Setup LOCAL : ComfyUI (Windows) + Orchestrateur (WSL)

## Architecture

```
[WSL Linux]                          [Windows]
Infographiste_IA                     ComfyUI
orchestrator.py  ──HTTP :8188──►    python main.py --listen 0.0.0.0
```

## 1. Lancer ComfyUI (PowerShell Windows)

**Important** : sans `--listen`, ComfyUI n'accepte que `localhost` Windows — WSL ne peut pas s'y connecter.

```powershell
cd C:\Users\sdesh\ComfyUI
.\venv\Scripts\Activate.ps1
python main.py --listen 0.0.0.0 --port 8188 --lowvram
```

Ou via le script fourni :

```powershell
# Copier scripts/run_comfyui_windows.ps1 dans C:\Users\sdesh\ComfyUI\ ou l'appeler directement
```

## 2. Vérifier la connectivité depuis WSL

```bash
# IP passerelle WSL → Windows
WIN_IP=$(ip route show default | awk '{print $3}')
curl -s "http://${WIN_IP}:8188/system_stats" | head -c 200
```

Si ça échoue :
- Vérifie que ComfyUI tourne avec `--listen 0.0.0.0`
- Autorise le port 8188 dans le pare-feu Windows si besoin

## 3. Configurer l'orchestrateur (WSL)

```bash
cd /home/sdesh/projects/Infographiste_IA
cp config/.env.example .env   # si pas déjà fait
# Éditer COMFY_LOCAL_URL avec l'IP passerelle :
#   COMFY_LOCAL_URL=http://172.24.160.1:8188

./scripts/bootstrap_venv.sh
source .venv/bin/activate
```

## 4. LoRA : chemins Windows vs WSL

Les LoRA doivent être dans le dossier ComfyUI Windows :

```
C:\Users\sdesh\ComfyUI\models\loras\
```

L'orchestrateur passe le **nom du fichier** (`my_lora.safetensors`) au workflow — ComfyUI le résout depuis son propre dossier `models/loras/`.

Pour entraîner localement puis utiliser :
1. Copier le `.safetensors` de `Infographiste_IA/lora/` vers `C:\Users\sdesh\ComfyUI\models\loras\`
2. Ou créer un lien symbolique WSL ↔ Windows

## 5. Workflow ComfyUI

1. Construis ton graphe dans l'UI ComfyUI (FLUX.1 / SDXL)
2. Menu → **Save (API Format)** → `workflows/workflow.json`
3. (Optionnel) Renseigne les node_id dans `config/config.yaml` :
   - `workflow.prompt_nodes`
   - `workflow.lora_nodes`

## 6. Générer

```bash
python orchestrator.py scan
python orchestrator.py generate \
  --workflow workflows/workflow.json \
  --prompt "Paysage fantasy brumeux, ruines anciennes" \
  --lora "my_lora.safetensors"
```

Résultat : `assets/images/`

## 7. Démarrage automatique Windows (au boot / connexion)

ComfyUI peut démarrer automatiquement à chaque connexion Windows via le **Planificateur de tâches**.

### Installation (une seule fois)

Ouvre **PowerShell en administrateur** sur Windows :

```powershell
cd \\wsl$\Ubuntu\home\sdesh\projects\Infographiste_IA\scripts\windows
Set-ExecutionPolicy -Scope Process Bypass
.\install_comfyui_autostart.ps1
.\open_firewall_comfyui.ps1
```

Ce que ça fait :
- Copie `start_comfyui.bat` dans `C:\Users\sdesh\ComfyUI\`
- Crée la tâche planifiée `ComfyUI-Infographiste` (démarrage à la connexion + 30s de délai)
- Lance avec `--listen 0.0.0.0 --port 8188 --lowvram` (compatible WSL + ta GTX 1050 Ti)
- Logs dans `C:\Users\sdesh\ComfyUI\user\boot.log`

### Tester sans redémarrer

```powershell
Start-ScheduledTask -TaskName "ComfyUI-Infographiste"
```

### Vérifier depuis WSL

```bash
WIN_IP=$(ip route show default | awk '{print $3}')
curl -s "http://${WIN_IP}:8188/system_stats" | head -c 200
```

### Désinstaller

```powershell
.\uninstall_comfyui_autostart.ps1
```

### Alternative simple (sans admin)

Copie `start_comfyui.bat` dans le dossier Démarrage Windows :

```
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\
```

Moins robuste (pas de relance auto en cas de crash), mais fonctionne sans droits admin.
