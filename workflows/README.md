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
| `workflow_sd15_lora_lowvram.json` | DreamShaper 8 + LoRA | 512×512 | Avec `--lora "fichier.safetensors"` |
| `workflow_sdxl_lowvram.json` | SDXL Base 1.0 | 768×768 | Nécessite `sd_xl_base_1.0.safetensors` |

> **FLUX.1** : non recommandé sur 4 Go VRAM. Préférer SD1.5/SDXL.

## Dataset NAS (inspiration MMORPG)

```bash
./scripts/mount_nas_dataset.sh
python orchestrator.py scan   # lit dataset/inspiration_mmorpg (symlink NAS)
```

Chemin NAS : `\\Nas_lbg\nas\...\Inspiration pour MMORPG` (~1588 images)

