# 3D Asset Library

This directory contains the game's source 3D models. Assets are grouped by purpose so the scene script can load them deliberately rather than placing every imported model in the starting scene.

## Folder map

- `characters/` — player characters and humanoid NPCs.
- `creatures/` — enemies, spirits, golems, and boss models.
- `environment/` — trees, rocks, mushrooms, roots, and outdoor scenery.
- `architecture/` — buildings, ruins, and structural pieces.
- `props/` — furniture, tables, books, and magical objects.
- `animations/` — animation exports and rig-compatibility notes.
- `materials-textures/` — standalone source textures and materials.

## Models currently connected to gameplay

- Player wizard: `characters/fantasy wizard 3d model.glb`
- Alternate player appearance: `characters/wizard robe 3d model.glb`
- Mathias: `characters/dark armored knight 3d model.glb` (temporary stand-in until a dedicated Battle Mage model is added)
- Town buildings: `architecture/fantasy cottage 3d model.glb`
- Blackwood trees: `environment/haunted blackwood tree 3d model.glb`
- Ambush enemies: `creatures/shadow+beast+3d+model.glb`
- First Trial guardian: `creatures/dark+fantasy+boss+3d+model.glb`

Other models are available for deliberate future integration; adding a file to a folder does not automatically place it in the game. The main scene stays minimal, and `main.gd` controls where active assets appear. If a model cannot be loaded, procedural visuals provide a fallback.

## Asset workflow

- Keep each source model in its category folder and preserve the exact path used by the game.
- Keep Godot-generated `.import` sidecars for source assets in version control.
- Large model files use Git LFS. Ensure Git LFS downloads real model data; an LFS pointer text file is not a usable GLB.
- Do not commit `.godot/`: it contains machine-generated import/editor cache and Godot recreates it automatically.
- Before renaming or moving a model, update its references in `main.gd` and check the Godot import/build.
