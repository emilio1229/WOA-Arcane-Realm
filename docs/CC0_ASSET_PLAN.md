# CC0 Asset Integration Plan

This project only imports third-party art when the exact source page confirms that attribution is not required.

## Imported and used

- Pack: Kenney Fantasy UI Borders
- Official page: https://kenney.nl/assets/fantasy-ui-borders
- License: Creative Commons CC0 1.0; attribution is not required.
- Imported file: `assets/cc0/fantasy-panel-frame.png`
- Usage: tinted decorative frame overlay on the existing title, character-creation, settings, and pause panels.
- Internal provenance: `assets/cc0/SOURCES.md` and `assets/cc0/manifest.json`.

## Approved for later review

- Pack: Kenney Roguelike/RPG Pack
- Official page: https://kenney.nl/assets/roguelike-rpg-pack
- License: Creative Commons CC0 1.0; attribution is not required.
- Intended use: terrain, buildings, interiors and props.
- Status: not imported yet. The pack uses 16×16 tiles and a 3/4 view, so it must be checked against the existing game's camera and art style before use. Do not bulk-import incompatible tiles just to increase asset count.

## Integration rules

1. Import only assets that have been individually checked and are useful to the game.
2. Preserve source assets and crop or optimize derivatives without damaging pixel edges.
3. Keep the WoA dark-purple, pink and arcane-gold look consistent.
4. Do not change player progression, story data, familiars, PvP/PvE systems, or the existing `/realm` entrance during an art pass.
5. Do not add assets requiring attribution. The internal source register is for maintenance and license verification, not an in-game credits screen.
6. Test the real deployed game and mobile layout before calling an asset pass complete.
