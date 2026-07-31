# Style Prime — sprites unités 2D

**Cible** : Prime Client top-down, cohérence type **jeton WC3** (même échelle, même palette, même rendu).

## Palette commune

| Rôle | Couleur dominante |
|------|-------------------|
| Joueurs bots | accents froids (bleu/vert/cyan) |
| Joueur officiel | bleu royal |
| NPC civil | tons sable / beige / cuir |
| Garde | acier + cuivre steampunk léger |

Teinte Godot : **35 % max** sur le sprite (`lerp` vers blanc) — différenciation sans casser le style.

## Prompt fixe (tous les sprites)

```
mmorpg_insp, prime_unit_token, 90 degree overhead, directly from above,
orthographic top-down game token, single miniature figure, circular footprint,
shoulders and back visible, no face, no front view,
stylized semi-realistic, retro 80s anime sci-fi, steampunk light cyberpunk,
painted metal and fabric, worn edges, clean silhouette, sharp focus,
plain neutral grey background, studio lighting, consistent scale
```

## Negative (tous)

```
isometric, perspective, 3/4 view, side view, front view, face visible,
eye contact, blurry, cluttered, multiple characters, giant, tiny,
text, watermark, deformed, photorealistic, messy background,
inconsistent style, different art style
```

## Variantes (suffixe uniquement)

| Clé | Suffixe prompt |
|-----|----------------|
| `player_lia` | female explorer, green desert cloak, slim |
| `player_nix` | male scout, blue tech gear, compact |
| `player_mira` | female pilot, magenta accent jacket |
| `player_teome` | male hero lead, blue official coat |
| `player_gally` | male mechanic, ochre work suit |
| `player_kael` | male fighter, violet armor trim |
| `player_bot` | neutral explorer gear |
| `npc_default` | civilian npc, simple desert clothes, unarmed |
| `npc_guard` | guard npc, light steampunk armor, helmet, compact |

## Paramètres ComfyUI (ne pas changer entre assets)

- Workflow : `workflow_sd15_lora_refined.json`
- LoRA : `mmorpg_insp_lora.safetensors` @ **0.6**
- CFG **6.5**, steps **28**, seed bloc **51xxx**

## Post-traitement

- `prepare_sprite.py` : crop alpha + fill **78 %**
- Déploiement : `deploy_sprites_to_prime.sh`

## Rendu Godot

- Socle ellipse sous chaque sprite (ombre + anneau) — `entity.gd`
- `display_px` : **42**
