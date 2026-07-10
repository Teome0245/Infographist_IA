# workflows/

Place ici tes workflows ComfyUI exportés depuis l'UI (menu **Save (API Format)**).

## Important : format attendu

L'orchestrateur attend un JSON de type "API format" avec une clé `prompt` (dictionnaire de nodes).

## Patch dynamique

L'orchestrateur peut :
- remplacer le texte du prompt dans certains nodes (ex: `CLIPTextEncode.inputs.text`)
- injecter le nom du LoRA dans les nodes de type `LoraLoader` (`inputs.lora_name`)

### Méthode recommandée (stable)

Dans `config/config.yaml`, renseigne :
- `workflow.prompt_nodes`: liste des node_id contenant le texte à remplacer
- `workflow.lora_nodes`: liste des node_id où fixer `lora_name`

## Workflows fournis

| Fichier | Modèle | Résolution | Usage |
|---------|--------|------------|-------|
| `workflow.json` → `workflow_sd15_lowvram.json` | DreamShaper 8 (SD1.5) | 512×512 | **Défaut — GTX 1050 Ti 4 Go** |
| `workflow_sd15_lora_lowvram.json` | DreamShaper 8 + LoRA | 512×512 | LoRA strength **0.8** (style fort) |
| `workflow_sd15_lora_refined.json` | DreamShaper 8 + LoRA | 512×512 | LoRA strength **0.6**, negative strict — **recommandé** |
| `workflow_sdxl_lowvram.json` | SDXL Base 1.0 | 768×768 | Nécessite `sd_xl_base_1.0.safetensors` |

> **FLUX.1** : non recommandé sur 4 Go VRAM. Préférer SD1.5/SDXL.

## Dataset NAS (inspiration MMORPG)

```bash
./scripts/mount_nas_dataset.sh
python orchestrator.py scan   # lit dataset/inspiration_mmorpg (symlink NAS)
```

Chemin NAS : `\\Nas_lbg\nas\...\Inspiration pour MMORPG` (~1588 images)

## Exemple LoRA affiné (`mmorpg_insp_lora`)

```bash
python orchestrator.py generate \
  --workflow workflows/workflow_sd15_lora_refined.json \
  --prompt "mmorpg_insp, small floating steampunk drone, brass body, mono-eye, clean silhouette, sharp focus" \
  --negative-prompt "blurry, messy, cluttered, extra parts, deformed, low quality" \
  --lora "mmorpg_insp_lora.safetensors" \
  --seed 42
```

Réglages du workflow refined : `strength_model/clip=0.6`, `cfg=6.5`, `steps=28`, negative strict par défaut.

