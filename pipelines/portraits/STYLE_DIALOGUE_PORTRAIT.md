# Style Dialogue Portrait — Prime Client

**Cible** : petite fenêtre portrait type Warcraft 3, lisible en UI, cohérente avec Prime.

## Usage

Ce style sert à générer des **portraits de dialogue** pour :
- joueur humain,
- compagnons,
- PNJ récurrents,
- rôles génériques (`bartender`, `guide`, `merchant`, etc.).

## Cadrage

- buste / épaules / visage
- caméra face légère ou 3/4 léger
- regard visible
- expression lisible sans pose extrême
- fond simple ou neutre

## Contraintes de cohérence

- conserver le **même costume**
- conserver la **même palette**
- conserver la **même silhouette**
- conserver la **même lumière**
- ne changer que l’expression ou le micro-état

## Style visuel

- semi-réaliste stylisé
- contours propres
- lisibilité UI
- visage net
- pas d’arrière-plan chargé
- pas de texte, watermark, cadre décoratif

## Expressions MVP

- `neutral`
- `happy`
- `angry`
- `sad`
- `surprised`
- `determined`

Les prompts d’expression doivent être **lisibles en petit panneau UI** : privilégier bouche/yeux/sourcils explicites, negative par expression (ex. interdire « bouche fermée » sur `talk_1`), et un **seed différent par expression** (décalage fixe) pour éviter un visage figé.

## Variantes futures

- `neutral_blink`
- `talk_1`
- `talk_2`

## Sortie recommandée

- format : PNG
- fond : transparent si possible, sinon neutre
- nommage : `character_id/expression.png`
