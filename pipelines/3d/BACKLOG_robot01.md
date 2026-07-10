# Drone steampunk (option A) — EN PAUSE jusqu'à infra LAN relancée

Style moodboard : Cowboy Bebop, Gunnm, Gun Frontier, Albator, FMA, Cobra.  
Type : **petit drone flottant** (pas de jambes, rig optionnel).

## Statut

- [x] Spéc technique (5–10k tris, 512/1024, Godot + web)
- [x] Prompts concept + multi-view définis
- [ ] Génération 4 vues — **après LoRA local OU infra 140 up**
- [ ] Pipeline image→3D — **après infra 140**

## Prompt base (à réutiliser)

```text
small floating drone robot, steampunk with light cyberpunk, retro-futuristic 80s anime,
cowboy bebop vibe, gunnm vibe, compact readable silhouette, mono-eye camera,
brass and painted steel, worn edges, grease, bolts, small pipes, rivets,
utility backpack, stylized but semi-realistic, neutral background, studio lighting
```

## Multi-view (quand on reprend)

| Fichier | Suffixe prompt |
|---------|----------------|
| `robot01_front.png` | `front view, centered, orthographic-like` |
| `robot01_side.png` | `left side view, orthographic-like` |
| `robot01_back.png` | `back view, orthographic-like` |
| `robot01_3q.png` | `three-quarter view, turntable` |

Sortie prévue : `pipelines/3d/outputs/multiview/robot01/` (sur NAS quand infra prête).

## Décision

**Option 1** : MVP sans LoRA possible, mais on **attend la relance 110/140** pour déporter le rendu H24 et ne pas charger le PC dev.
