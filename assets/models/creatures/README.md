# Creatures

Creature models live here:

- `shadow+beast+3d+model.glb` — used for the opening ambush enemies.
- `dark+fantasy+boss+3d+model.glb` — used for the first trial guardian.
- `haunted+forest+spirit+3d+model.glb` — available for future integration.
- `stone+golem+3d+model.glb` — available for future integration.

Only models explicitly referenced by `main.gd` are loaded into gameplay. Keep the procedural fallback when integrating a new model so a missing asset does not prevent the scene from opening.
