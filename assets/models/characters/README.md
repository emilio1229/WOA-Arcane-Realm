# Characters

Character source models live here. Current integrations:

- `fantasy wizard 3d model.glb` — default player appearance.
- `wizard robe 3d model.glb` — selectable alternate appearance.
- `dark armored knight 3d model.glb` — currently used as Mathias's visual stand-in.

A dedicated Battle Mage/Mathias model is not currently present in this folder. Until one is added, the game uses the armored character model and keeps its procedural fallback.

Keep character models as GLB files with their materials/textures and import metadata. New models do not become selectable automatically: wire them into the character selection and model-loading code, then test in Godot.
