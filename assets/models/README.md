# Tripo model import guide

The game supports optional Tripo-generated GLB models. Keep these files in this folder using the exact filenames below; the game will use a model automatically when present and keep its procedural fallback if a file is missing.

## Priority models

1. player_apprentice.glb — the player's apprentice wizard.
2. mathias_keeper.glb — Mathias, the elderly sanctuary keeper.
3. sanctuary_guardian.glb — the first trial boss.
4. haunted_tree.glb — the blackwood trees scattered around the sanctuary.

## Shared export requirements

- Export as **glTF Binary (.glb)** with materials/textures embedded.
- Use a stylized dark-fantasy game-art style, not photorealism.
- Keep the model centered on the X/Z axes, with its feet or base at ground level (Y = 0).
- Face characters toward **-Z** (Godot's forward direction).
- Avoid a large ground plane, scenery, captions, logos, or floating presentation elements.
- Keep textures sensible for a browser game (ideally 1K–2K); avoid unnecessarily dense geometry.
- A static mesh is fine for the first pass. Rigging/animation can be added as a later pass.
- After downloading, place the file directly in assets/models/ with the exact filename listed above, then commit it to the repository. Do not rename the code's expected filenames unless the code is updated too.

## Tripo prompts

### player_apprentice.glb

Stylized 3D fantasy game character, full-body young apprentice wizard for a haunted magical realm. Deep violet layered travel robes, slightly oversized pointed wizard hat, muted antique-gold trim, leather belt, sturdy boots, a wooden staff with one glowing violet crystal. Eerie but heroic, readable silhouette, handcrafted stylized materials, medium-low polygon game asset, clean topology, no base or background, neutral A-pose with arms slightly away from the body, feet on ground at origin, facing -Z. Approximately 1.8 meters tall. No text, no watermark.

### mathias_keeper.glb

Stylized 3D fantasy NPC, full-body elderly wizard and keeper of an ancient sanctuary. Long silver-gray beard, weathered face, layered plum and midnight-purple robes, dark mantle, crooked pointed hat with a small antique-gold band, old wooden staff topped with a soft violet crystal. Kind but mysterious, haunted fantasy game aesthetic, strong readable silhouette, handcrafted stylized materials, medium-low polygon game asset, clean topology, no base or background, relaxed standing pose, feet on ground at origin, facing -Z. Approximately 2.6 meters tall including hat. No text, no watermark.

### sanctuary_guardian.glb

Stylized 3D dark-fantasy boss creature for a magical ruin. Towering ancient guardian in cracked blackened stone armor, broad shoulders, heavy forearms, jagged horn-like crown, glowing magenta-violet core embedded in the chest, subtle luminous runes carved into the armor, threatening but clearly readable silhouette. Dark charcoal stone, muted iron, restrained purple and magenta emissive accents. Medium-low polygon game asset, clean topology, no weapon larger than the body, no base or background, neutral idle pose with feet on ground at origin, facing -Z. Approximately 3.2 meters tall. No text, no watermark.

### haunted_tree.glb

Stylized 3D haunted blackwood tree for a dark fantasy game environment. Twisted near-black trunk, crooked bare branches reaching upward like claws, sparse sickly deep-green moss and tiny faint green bioluminescent growths, ancient and eerie silhouette. No leaves canopy, no ground plane, no rocks, no background. Medium-low polygon environment prop, readable shape from a distance, game-ready materials, trunk base centered at origin, approximately 3 meters tall. No text, no watermark.

## How the game uses the models

The current game checks these paths when creating the player, Mathias, guardian, and trees. If a matching GLB is missing or cannot be loaded, the existing procedural visuals remain as a fallback. This lets us add assets one at a time without breaking the game or its browser build.


## Where to put your new batch of models

The repository now has category folders so you can sort the models from your one big Tripo prompt:

- `characters/` — wizard, battlemage, Wizardrobe, NPCs, and other people.
- `environment/` — trees, rocks, roots, mushrooms, plants, and outdoor scenery.
- `architecture/` — ruins, towers, walls, arches, stairs, doors, and dungeon pieces.
- `props/` — books, chests, potions, lanterns, altars, crystals, and furniture.
- `creatures/` — monsters, spirits, golems, and creature variants.
- `materials-textures/` — only textures/material files exported separately from a model.
- `animations/` — animation exports or temporary animation source files while we check rig compatibility.

Each folder has its own README with more specific guidance. Git doesn't preserve empty folders, so the README files are what create and document these folders.

### One important distinction

These category folders are for organizing and reviewing your assets. Most new models will **not appear in the game automatically** just because they are uploaded. The current four optional model slots still expect these exact paths directly in this folder: `player_apprentice.glb`, `mathias_keeper.glb`, `sanctuary_guardian.glb`, and `haunted_tree.glb`. Once you upload the batch, I can identify which models fit those slots and integrate the others into the world deliberately.

For Godot, `.glb` is the easiest option when it includes its materials and textures. Godot supports glTF 2.0 and imports it from within the project. See the [Godot 4.7 import documentation](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/index.html).
