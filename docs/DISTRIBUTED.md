# Mode DISTRIBUTED (Infra 110 / 140)

Voir **`docs/INFRA_LAN.md`** pour la topologie complète (Proxmox, NAS, systemd, Nginx).

## Résumé LAN

| Cible | URL ComfyUI | Usage |
|-------|-------------|-------|
| **140** (recommandé) | `http://192.168.0.140:8188` | GPU worker direct |
| **110** (proxy) | `http://192.168.0.110:8189` | Nginx → 140 |

## Activation (poste dev)

```bash
./scripts/switch_infra.sh distributed
./scripts/healthcheck_lan.sh
```

## Variables

Voir `config/.env.distributed.example` :

- `INFRA_MODE=DISTRIBUTED`
- `INFRA_TARGET=140`
- `STORAGE_BACKEND=NAS`
- `NAS_MOUNT_PATH=/mnt/nas_lbg/Infographiste_IA`

## Stockage NAS

Dataset, LoRA, assets et exports `.glb` sur :

`//Nas_lbg/nas/LBG_Cloud_Drive/Infographiste_IA`

Script montage Debian (VM) : `infra/scripts/mount_nas_debian.sh`

## Endpoint ComfyUI

- `POST /prompt`
- `GET /history/<prompt_id>`
- `GET /view?filename=...`

Auth optionnelle : `COMFY_AUTH_HEADER` / `COMFY_AUTH_VALUE`

## S3 (plus tard)

Le backend S3 reste disponible si tu passes sur MinIO ; pour l'instant **NAS uniquement**.

