# Pipeline 2D top-down — Prime Client

Génération de **sprites unitaires** (vue du dessus) via ComfyUI + LoRA `mmorpg_insp`.

## Prompts type

- **Top-down** (pas isométrique) : `top-down view, bird eye view, orthographic top-down`
- **Negative** : `isometric, perspective, 3/4 view, multiple characters`
- Trigger LoRA : `mmorpg_insp`

## Générer les sprites de base

```bash
cd ~/projects/Infographiste_IA
./scripts/generate_sprites_prime_topdown.sh
```

ComfyUI doit tourner (`./scripts/start_session_local.sh`).

## Déployer vers Prime Client

```bash
./scripts/deploy_sprites_to_prime.sh
```

Copie + resize (~128 px) + détourage optionnel →  
`new_mmo/prime-client/assets/sprites/units/`

## Intégration Godot

- Manifest : `prime-client/config/sprite_manifest.json`
- Code : `scripts/sprite_registry.gd`, `entity.gd` (fallback cercle si PNG absent)
- Recharger Prime Client → les bots/NPC affichent le sprite dès que le PNG existe

## Priorité assets

1. `player_bot.png` — Nix, Lia, Mira (vert → sprite)
2. `npc_default.png` — PNJ hub
3. `npc_guard.png` — garde-mécha, sergent
4. (plus tard) icônes POI `assets/sprites/poi/`
