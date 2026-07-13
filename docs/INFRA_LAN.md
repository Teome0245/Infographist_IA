# Infra LAN LBG — Proxmox + 110/140 + NAS

Objectif : faire tourner ComfyUI (et plus tard LoRA / 3D) **H24 sur GPU** en déportant depuis le poste dev WSL.

## Topologie (état actuel : **pas de GPU sur 110 ni 140**)

```
[Poste dev — GTX 1050 Ti]          [LAN 192.168.0.0/24 — CPU only]
ComfyUI + kohya + rendu 2D    ◄──  110 : LLM, Nginx, orchestration légère
       │                           140 : backend API, jobs CPU, stockage NAS
       └─ sync ─────────────────►  NAS //Nas_lbg/nas/.../Infographiste_IA
```

| VM | IP | GPU | Rôle **aujourd'hui** |
|----|-----|-----|----------------------|
| **110** | `192.168.0.110` | Non | Front, Ollama `:11434`, Nginx (futur proxy) |
| **140** | `192.168.0.140` | Non | Backend, jobs CPU, point de montage NAS |
| **PC dev** | WSL + Windows | **GTX 1050 Ti** | **ComfyUI, LoRA, tout rendu IA** |
| **NAS** | `Nas_lbg` | — | Stockage partagé |

> **Quand un GPU sera ajouté sur 140** (ou 110), on déportera ComfyUI + LoRA + 3D en H24.  
> Jusque-là : `INFRA_MODE=LOCAL` pour la génération ; le LAN sert surtout au **stockage NAS** et à l'**orchestration / LLM**.

OS attendu : **Debian** (à confirmer au boot : `cat /etc/os-release`).

Compte VM existant LBG : **`lbg`** (cf. `LBG_IA_MMO`).

## Rôles des machines

### 140 — Backend (CPU pour l'instant)
- Montage NAS lecture/écriture
- Sync dataset / assets / LoRA depuis le PC dev
- **Pas de ComfyUI** tant qu'il n'y a pas de GPU (ou GPU trop faible)
- Plus tard (avec GPU) : ComfyUI `:8188`, kohya, Blender headless H24

### 110 — Front / LLM
- Ollama `:11434` (déjà en place)
- Nginx proxy ComfyUI → **inutile sans GPU sur 140**
- Peut héberger scripts d'orchestration légers, UI, healthchecks

### Poste dev (WSL + Windows)
- Orchestration, tests, petits jobs
- Bascule `INFRA_MODE=LOCAL` ou `DISTRIBUTED` via `.env`

## Stockage NAS (convention)

Sur chaque VM Debian :

```
/mnt/nas_lbg/Infographiste_IA/
├── dataset/           # inspirations, kohya_train
├── lora/              # .safetensors
├── assets/images/     # rendus 2D
├── exports_3d/        # .glb Godot / web
└── logs/
```

UNC Windows : `\\Nas_lbg\nas\LBG_Cloud_Drive\Infographiste_IA`  
(à créer sur le NAS si absent)

## Checklist relance infra

### 1. Proxmox + VMs
```bash
ping -c 2 192.168.0.110
ping -c 2 192.168.0.140
ssh lbg@192.168.0.140 'uname -a; cat /etc/os-release | head -3'
ssh lbg@192.168.0.110 'uname -a; cat /etc/os-release | head -3'
```

### 2. GPU sur 140
```bash
ssh lbg@192.168.0.140 'nvidia-smi'   # échouera tant qu'aucun GPU n'est passé à la VM
```
**Sans GPU** : sauter les étapes ComfyUI systemd sur 140.

### 3. Monter le NAS sur 140 (et 110 si besoin)
```bash
# Depuis le repo, sur la VM :
sudo bash infra/scripts/mount_nas_debian.sh
```

### 4. ComfyUI sur 140 — **uniquement après ajout GPU (PCI passthrough ou autre)**

```bash
# À faire quand 140 aura un GPU utilisable
sudo bash infra/scripts/install_comfyui_systemd_140.sh
curl -s http://192.168.0.140:8188/system_stats | head -c 200
```

### 5. Proxy Nginx sur 110 — **optionnel, après GPU sur 140**
```bash
sudo cp infra/nginx/comfyui_110.conf.example /etc/nginx/sites-available/comfyui-infographiste
sudo ln -sf /etc/nginx/sites-available/comfyui-infographiste /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
curl -s http://192.168.0.110:8189/system_stats | head -c 200
```

### 6. Basculer l'orchestrateur (poste dev)

**Tant qu'il n'y a pas de GPU sur 140** : rester en `INFRA_MODE=LOCAL` (ComfyUI sur le PC).

```bash
./scripts/switch_infra.sh local
```

Quand 140 aura un GPU :
```bash
cp config/.env.distributed.example .env
./scripts/switch_infra.sh distributed
```

## Ce qu'on peut déporter **sans GPU** (dès que le NAS est monté)

| Tâche | Machine | Faisable ? |
|-------|---------|------------|
| Stockage dataset / LoRA / assets | NAS via 140 | Oui |
| Sync rsync PC → NAS | 140 ou dev | Oui |
| Orchestration + LLM (prompts, QC texte) | 110 Ollama | Oui |
| Rendu ComfyUI / LoRA / 3D | 140 ou 110 | **Non** — reste sur PC dev |
| ComfyUI H24 | 140 | **Après ajout GPU** |

## En attendant la relance infra

- **LoRA local** (200 images) sur PC + stockage **B:** — continuer
- **Génération 2D** : PC Windows ComfyUI (`INFRA_MODE=LOCAL`)
- **Relance 110/140** : priorité **NAS monté** + services LBG existants, pas ComfyUI
- **Drone steampunk** : pause (backlog `pipelines/3d/BACKLOG_robot01.md`)

## Sécurité minimale LAN

- ComfyUI **non exposé** sur Internet sans proxy + auth
- Firewall : `8188` autorisé LAN uniquement sur 140
- Nginx 110 : basic auth ou token si exposé hors LAN

## Liens projet LBG

- User VM : `lbg@192.168.0.140`
- Ollama front : `http://192.168.0.110:11434`
- UI pilot : `http://192.168.0.110:8080/pilot/v2/`
