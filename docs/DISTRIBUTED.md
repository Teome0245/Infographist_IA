# Mode DISTRIBUTED (Infra 110 / 140)

Objectif : utiliser le même `orchestrator.py` mais en routant vers un endpoint distant (ComfyUI managé) et en gérant un stockage partagé (ex: S3).

## Variables d'environnement

Voir `config/.env.example`. Les plus importantes :

- `INFRA_MODE=DISTRIBUTED`
- `INFRA_TARGET=110` (ou `140`)
- `COMFY_REMOTE_URL_110` / `COMFY_REMOTE_URL_140`
- `S3_BUCKET`, `S3_PREFIX`, `AWS_REGION`
- `COMFY_JOB_TIMEOUT_S` plus élevé (batchs lourds)

## Stockage (ex: S3)

Deux stratégies possibles :

1) **Uploader le `dataset/`** et entraîner le LoRA sur l'infra (si tu as un job d'entraînement côté infra).
2) **Entraîner localement**, puis uploader le LoRA `.safetensors` vers S3, et faire pointer ComfyUI distant vers cet objet (selon ta manière de déployer ComfyUI).

Script d'upload :

```bash
export S3_BUCKET="..."
export S3_PREFIX="infographiste-virtuel"
./scripts/upload_to_s3.sh dataset
./scripts/upload_to_s3.sh lora/my_lora.safetensors
```

## Endpoint ComfyUI distant

Le code suppose que l'API ComfyUI est exposée via :
- `POST /prompt`
- `GET /history/<prompt_id>`
- `GET /view?filename=...&subfolder=...&type=...`

Si ton infra passe par un proxy (auth, prefix path), adapte `base_url` dans `config/config.yaml` ou via env.

## Sécurité

Recommandations (à implémenter côté infra) :
- mTLS ou JWT/Bearer token côté gateway
- allowlist IP / VPN
- rate limiting par client

Le client Python accepte des headers custom via env `COMFY_AUTH_HEADER` / `COMFY_AUTH_VALUE` (voir config du module).

