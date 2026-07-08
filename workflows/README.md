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

Si ces listes sont vides, le patch est fait par heuristique (class_type connus).

