# Pygmalion v1

Mini-cadre d'iteration pour affiner les capacites de l'infographiste `Pygmalion`.

Objectif : comparer des generations de facon reproductible, avec des prompts stables, des seeds fixes, et des criteres d'evaluation simples.

## Regles du protocole

- Ne changer qu'un seul levier a la fois.
- Garder le meme workflow pendant une serie complete.
- Garder les memes seeds de reference pour comparer les versions.
- Nommer les essais par mode : `character_v1`, `world_v1`, puis `v2`, `v3`, etc.
- Evaluer chaque image avant de relancer une nouvelle serie.

## Workflow de base

- Workflow recommande : `workflows/workflow_sd15_lora_refined.json`
- LoRA : `mmorpg_insp_lora.safetensors`
- Resolution : celle du workflow exporte
- LoRA strength de depart : `0.6`

## Mode 1: Character Sheet

### Intention

Produire des personnages lisibles, full body, avec une meilleure finesse du visage, des materiaux et des accessoires.

### Prompt maitre v1

```text
mmorpg_insp, full body character sheet, fantasy MMO character concept, neutral studio background, clean silhouette, refined facial features, sharp eyes, subtle skin detail, intricate clothing seams, layered materials, polished accessories, game-ready concept art
```

### Negative prompt v1

```text
blurry, low quality, deformed face, asymmetrical eyes, bad anatomy, bad hands, extra fingers, extra limbs, cropped, close-up, watermark, text, logo, anime, manga, chibi
```

### Seeds de reference

- `1401`
- `1402`
- `1403`

### Variantes a tester

#### Variante A - lisibilite

```text
full body character sheet, neutral studio background, clean silhouette, front-facing pose
```

#### Variante B - details visage

```text
refined facial features, sharp eyes, subtle skin detail, realistic face proportions
```

#### Variante C - details costume

```text
intricate fabric seams, leather stitching, belt pouches, buckles, layered costume materials
```

### Criteres de notation

Noter chaque image de `1` a `5`.

- Visage : finesse, symetrie, regard, lisibilite
- Anatomie : proportions globales, mains, posture
- Costume : richesse des details, materiaux, cohérence
- Silhouette : lecture immediate de la classe/persona
- Cohesion MMO : impression "concept art de jeu", pas "mode/fashion"

## Mode 2: Worldbuilding

### Intention

Produire des cartes, villes et points d'interet lisibles, sans derive vers ville moderne, photo realiste ou scene de personnage.

### Prompt maitre v1

```text
mmorpg_insp, fantasy worldbuilding concept art, readable layout, strong landmarks, coherent geography, clear points of interest, exploration-focused MMORPG visual design
```

### Negative prompt v1

```text
modern skyscraper, car, highway, realistic photograph, blurry, portrait, close-up face, single centered character, watermark, logo, unreadable text block
```

### Seeds de reference

- `2401`
- `2402`
- `2403`

### Sous-modes

#### Carte monde

```text
hand-drawn fantasy world map on parchment, clear coastlines, mountain ranges, forests, biomes, compass rose, cartography style, no modern elements
```

#### Ville

```text
bird's-eye fantasy city layout, districts, walls, harbor, roads, landmark buildings, strategy map style, no skyscrapers
```

#### Region / POI

```text
regional adventure map with ruins, villages, forests, shrines, roads, annotated icon style, tabletop RPG cartography
```

### Criteres de notation

Noter chaque image de `1` a `5`.

- Lisibilite : comprend-on vite ce qu'on regarde ?
- Cohérence spatiale : geographie, routes, quartiers, biomes
- Landmarks : presence de points d'interet memorables
- Style : carte/ville MMO, pas photo ou ville moderne
- Exploitabilite : image utile pour worldbuilding, level design ou lore

## Boucle d'iteration conseillee

1. Lancer `3` images par mode avec les seeds de reference.
2. Garder uniquement les `1` ou `2` meilleurs resultats.
3. Identifier un seul defaut principal :
   - visage trop faible
   - details costume trop pauvres
   - carte illisible
   - derive moderne
4. Modifier uniquement :
   - le prompt maitre, ou
   - le negative prompt, ou
   - la force du LoRA
5. Relancer avec les memes seeds.

## Journal de test minimal

Pour chaque serie, noter :

- Version : `character_v1`, `world_v1`, etc.
- Workflow utilise
- LoRA strength
- Seeds
- Prompt
- Negative prompt
- Top 2 images
- Defaut principal observe
- Decision pour la version suivante

## Commande type

```bash
python orchestrator.py generate \
  --workflow workflows/workflow_sd15_lora_refined.json \
  --prompt "mmorpg_insp, full body character sheet, fantasy MMO character concept, neutral studio background, refined facial features, intricate costume details" \
  --negative-prompt "blurry, low quality, deformed face, bad hands, extra fingers, cropped, anime" \
  --lora "mmorpg_insp_lora.safetensors" \
  --seed 1401
```
