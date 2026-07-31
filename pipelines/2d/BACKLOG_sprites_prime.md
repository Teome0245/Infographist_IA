# Backlog sprites 2D — Prime Client

**Priorité** : différencier joueurs + vraie vue top-down (Team Infographiste / Pygmalion).

## Fait (juil. 2026)

- [x] Pipeline ComfyUI → deploy → `entity.gd`
- [x] Sprites génériques bot / NPC / garde
- [x] **Teintes par joueur** (Lia, Nix, Mira, Teome…) — immédiat sans regénérer
- [x] **Jitter** d’affichage si plusieurs entités au même point (hub)
- [x] Manifest `name_exact` par joueur

## À faire (Team)

| Tâche | Owner | Détail | Statut |
|-------|-------|--------|--------|
| Fond planète visible (PNG fallback) | Cursor + Iris | `tatooine.png` + loaders PNG-first | **Fait 2026-07-25** |
| Login panel space-western | Iris | thème + dim + panel | **Fait 2026-07-25** |
| Regénérer sprites **overhead strict** | Infographiste IA / Pygmalion | `./scripts/generate_sprites_prime_topdown.sh` (prompts v2) — **ComfyUI requis** | **Fait 2026-07-25** (Lia/Nix/Mira/Teome/Gally/Kael/bot + NPC) |
| Valider silhouettes Lia/Nix/Mira | Humain + Pilot | F5 Prime Client, hub LH | **À valider** |
| Sprites **POI** (hub, cantina, banque) | Infographiste IA | `pipelines/2d/poi/` | À faire |
| Atlas / sprite sheet animations | Plus tard | idle 2–4 frames type WC3 | Plus tard |
| Post-traitement top-down | Script | `prepare_sprite.py` : crop cercle, renforcer contraste | À faire |

### Vague esthétique 2026-07-25
- Tasks P03 : Pygmalion `a549727c…`, Iris `ad5ad47f…` (sondes L1 OK ; génération assets = job ComfyUI/timer sprites).
- Bloqueur sprites : ComfyUI down (`:8188`). Relancer puis `generate_sprites_prime_topdown.sh` + `deploy_sprites_to_prime.sh`.

## Prompts top-down (rappel)

Voir **`STYLE_PRIME.md`** — bloc prompt identique pour tous les assets, seul le suffixe personnage change.

- **Oui** : `prime_unit_token`, `90 degree overhead`, `consistent scale`
- **Non** : `isometric`, `different art style`, `face visible`

## Différenciation joueurs

1. **Court terme** : `player_tints` dans `sprite_manifest.json` (déjà actif)
2. **Moyen terme** : PNG dédié `player_lia.png`, `player_nix.png`, …
3. **Long terme** : brief par personnage (tenue, rôle) dans dataset LoRA

## Commandes

```bash
cd ~/projects/Infographiste_IA
./scripts/generate_sprites_prime_topdown.sh
./scripts/deploy_sprites_to_prime.sh
```

Godot : recharger Prime Client → F5.
