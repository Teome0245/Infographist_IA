# Pygmalion - Evaluation v1

Premiere note d'evaluation sur les images deja generees, pour guider `v2`.

## Resume rapide

- **Personnages** : direction prometteuse.
- **Environnements purs** : bons resultats sur biomes et sanctuaires.
- **Cartes / villes** : encore instables, derive frequente vers image d'illustration plutot que vraie cartographie.

## Character Sheets - lecture v1

### Points forts

- Bonne silhouette globale sur plusieurs sorties.
- Certaines images ont un rendu "concept art jeu" credible.
- Les poses full body passent correctement.
- Les matieres principales commencent a etre lisibles.

### Defauts recurrents

- Visages encore trop mous ou peu precis.
- Manque de micro-details sur les coutures, accessoires et textures.
- Derive occasionnelle vers sci-fi / bodysuit glossy.
- Cohesion de classe parfois floue.

### Images notables

- `mmorpg_refined_00065_.png` : base interessante, mais encore generique.
- `mmorpg_refined_00066_.png` : silhouette propre, rendu exploitable.
- `mmorpg_refined_00068_.png` : bon niveau de lisibilite generale.
- `mmorpg_refined_00069_.png` : creature/personnage original, mais direction plus creature concept que character sheet classique.

### Decision v2

- Forcer davantage le mode `neutral background + full body + face detail`.
- Mieux verrouiller le style fantasy MMO et eviter les accents trop sci-fi.
- Ajouter des tokens de details visage et costume dans le prompt maitre.

## Worldbuilding - lecture v1

### Points forts

- Le LoRA sait produire des ambiances de biome et de sanctuaire convaincantes.
- Les ruines, forets et points d'interet naturels sont plutot bons.
- Les images ont souvent une bonne atmosphere.

### Defauts recurrents

- Les cartes ressemblent encore trop a des illustrations decoratives.
- Les villes derapent facilement vers du moderne ou du mixe incoherent.
- La lisibilite fonctionnelle d'une carte reste faible.
- Les vues "layout / top-down / strategy map" ne sont pas encore assez verrouillees.

### Images notables

- `mmorpg_refined_00070_.png` : esprit carte present, mais lisibilite encore insuffisante.
- `mmorpg_refined_00071_.png` : belle ville/canal, plus illustration que layout.
- `mmorpg_refined_00072_.png` : bon biome, utilisable comme concept environnemental.
- `mmorpg_refined_00073_.png` : variation interessante, mais pas encore exploitable comme carte.
- `mmorpg_refined_00074_.png` : echelle ambitieuse, mais derive sur la structure urbaine.

### Decision v2

- Scinder clairement `map mode` et `environment mode`.
- Pour `map mode`, insister sur :
  - `top-down`
  - `cartography`
  - `readable layout`
  - `annotated icons`
  - `parchment`
- Pour `city mode`, demander :
  - `bird's-eye`
  - `district layout`
  - `walls, harbor, roads`
  - `no skyscrapers`

## Priorites pour v2

### Personnages

1. Finesse visage
2. Materiaux et accessoires
3. Cohesion de classe
4. Anti-derive sci-fi trop forte

### Worldbuilding

1. Lisibilite de carte
2. Topologie / layout
3. Verrouillage anti-moderne
4. Distinction nette entre carte, ville, biome

## Piste retenue pour character_v2

Le meilleur levier immediat est de renforcer le prompt sur :

- `refined facial features`
- `balanced facial proportions`
- `sharp eyes`
- `subtle skin texture`
- `intricate leather stitching`
- `layered cloth`
- `polished buckles`

Et de durcir le negative contre :

- `plastic skin`
- `waxy skin`
- `close-up portrait crop`
- `anime`
- `chibi`

## Commandes utiles

### Character v1

```bash
./scripts/generate_pygmalion_character_v1.sh
```

### World v1

```bash
./scripts/generate_pygmalion_world_v1.sh
```

### Character v2

```bash
./scripts/generate_pygmalion_character_v2.sh
```
