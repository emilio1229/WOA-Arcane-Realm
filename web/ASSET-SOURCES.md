# Arcane Realm — 2D environment asset sources

The environment is being shaped as a readable 3/4/isometric fantasy RPG town. Import only art whose pack license is verified and whose perspective matches the map.

## CC0 candidate packs (attribution not required)

- Kenney Sketch Town — isometric town and landscape pieces, CC0: https://kenney.nl/assets/sketch-town
- Kenney Sketch Town Expansion — matching extra town pieces, caves, farms and roof corners, CC0: https://kenney.nl/assets/sketch-town-expansion
- Kenney Isometric Dungeon Tiles — floors, walls, furniture, stairs, crates and barrels, CC0: https://kenney-assets.itch.io/isometric-dungeon-tiles
- Kenney Isometric Library Tiles — shelves, tables and library interior pieces, CC0: https://kenney-assets.itch.io/isometric-library-tiles

CC0 permits use and modification without attribution. Do not redistribute a raw asset pack as a standalone product. Re-check the pack's included license file when importing files into this repository.

## Integration notes

- Keep a consistent 3/4/isometric projection; do not mix orthographic top-down tiles into this scene.
- Use town pieces for the Outer Ward, library pieces for the Codex/Archive interior, and dungeon pieces for rift/cave encounters.
- Tint compatible pieces toward WOA's dusk-purple palette in-engine; preserve contrast for paths, NPCs and interaction targets.
- Store imported files under `web/assets/isometric/` and retain the original license/readme alongside them.
- The current Outer Ward renderer is Phaser-drawn placeholder geometry, not imported sprites. The CC0 packs above are candidate sources for a later asset-import pass; this file does not claim they have already been bundled.
