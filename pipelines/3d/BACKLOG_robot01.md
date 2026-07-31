# Drone steampunk robot01 — option A (flottant)

Style : Cowboy Bebop, Gunnm, Gun Frontier, Albator, FMA, Cobra.  
LoRA : `mmorpg_insp_lora.safetensors` (1588 images, 3 epochs)

## Statut

- [x] Spéc technique (5–10k tris, 512/1024, Godot + web)
- [x] LoRA complet entraîné
- [x] **Multi-view 4 vues générées** (11 juil. 2026)
- [x] Pipeline image→3D TripoSR (vue **back round**)
- [x] Export `.glb` Godot (`robot01_round_godot.glb`, ~8k tris, texture 1024)

## Fichiers multi-view

```
B:\Infographiste_IA\pipelines\3d\outputs\multiview\robot01\
├── robot01_front.png
├── robot01_side.png
├── robot01_back.png
└── robot01_3q.png
```

Seeds : 42001–42004 | Workflow : `workflow_sd15_lora_refined.json`

## Regénérer

```bash
./scripts/generate_robot01_multiview.sh
# ou une vue : modifier le script / orchestrator.py generate
```

## Prochaine étape — 3D

1. ~~Choisir la meilleure vue~~ → **robot01_round_back.png**
2. ~~Retopo ~8k tris, UV, bake textures 512/1024~~ → fait via TripoSR + `pack_glb.py` + `simplify_mesh.py`
3. Importer `robot01_round_godot.glb` dans Godot (échelle / pivot) — **fait** (`lbg_client_godot`)
4. (Optionnel) variante web plus légère (~5k tris)
5. **Pause 3D** (juil. 2026) — priorité Prime Client 2D ; reprise 3D / hybride WC3 plus tard
