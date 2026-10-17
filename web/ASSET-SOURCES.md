# Arcane Realm — isometric art and licensing

## Original sprites now included

These custom SVG sprites were authored specifically for WOA Arcane Realm and do not require third-party attribution:
- `web/assets/isometric/player-wizard.svg` — playable wizard
- `web/assets/isometric/mathias.svg` — Mathias
- `web/assets/isometric/archivist.svg` — Archivist

The Phaser town scene loads these images from `/assets/isometric/`. The Nginx Docker image copies `web/assets/` into its served asset directory. The map terrain is currently generated from Phaser graphics; the next art pass can replace compatible terrain props with a CC0 tileset.

## CC0 packs for future environment expansion

The following official pack pages identify their assets as CC0 1.0, which permits use without mandatory attribution. Check the downloaded pack's own license file before importing:
- Kenney Sketch Town — isometric town and landscape pieces: https://kenney-assets.itch.io/sketch-town
- Kenney Isometric Dungeon Tiles — dungeon pieces and includes character sprites: https://kenney-assets.itch.io/isometric-dungeon-tiles
- Kenney Isometric Library Tiles — shelves, tables, library interior pieces and character sprites: https://kenney-assets.itch.io/isometric-library-tiles
- Kenney Roguelike Characters — character parts and equipment sprites: https://kenney.nl/assets/roguelike-characters

## Integration rules

- Keep a consistent 3/4/isometric projection; don't mix orthographic top-down tiles into the scene.
- Use town pieces for the Outer Ward, library pieces for the Codex/Archive interior, and dungeon pieces for rift/cave areas.
- Tint compatible pieces toward WOA's dusk-purple palette while preserving contrast for paths, NPCs, and interaction targets.
- Store imported files under `web/assets/isometric/` and retain their original license/readme.
- Keep the game's story, profile, inventory, familiars, and PvP/PvE data separate from decorative art changes.
