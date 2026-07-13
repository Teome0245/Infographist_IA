# dataset/

Dépose ici tes images de référence (inspirations) pour l'entraînement LoRA.

## Organisation recommandée (multi-styles)

```
dataset/inspiration_mmorpg/
  styles/                      # tri manuel ou auto (classify --sort-to)
    tatooine_desert/
    cantina_interior/
  inbox/                       # images à classer automatiquement
```

Les profils de style sont définis dans `config/art_styles.json`.

## Commandes Pygmalion / Infographiste_IA

```bash
# Inventaire + classification par style (JSON pour l'orchestrateur)
python orchestrator.py classify --json

# Ranger en symlinks par style
python orchestrator.py classify --sort-to dataset/styles_sorted

# Préparer un dataset Kohya **par** LoRA (pas un seul fourre-tout)
python orchestrator.py prepare-styles --json
```

Depuis l'équipe virtuelle (Pilot `#/team`) : objectif contenant `lora`, `inspiration` ou `classifier`
→ sonde `inspiration_probe` via Pygmalion.

Variables côté orchestrateur LBG :
- `LBG_INFOGRAPHISTE_IA_ROOT` — chemin vers ce dépôt
- `LBG_INFOGRAPHISTE_DATASET_DIR` — override du dossier images

Recommandations :
- Regroupe par thème dans des sous-dossiers (ex: `tatooine/`, `cantina/`).
- Utilise des noms de fichiers explicites (`tatooine_sand_dune_01.png`).
- Pour Kohya, ajoute des captions `.txt` associées aux images si tu veux un contrôle fin.

