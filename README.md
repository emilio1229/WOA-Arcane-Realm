# WOA: Arcane Realm — Fresh 2D Foundation

This branch is a clean restart of the **2D pixel-art RPG**. It preserves the agreed story and art direction, not the previous prototype implementation or third-party asset collections.

## Non-negotiable direction
- Pure 2D pixel-art game. No 3D engine, models, FBX, or 3D asset pipeline.
- Dark fantasy: near-black and deep violet environments, magenta arcane light, restrained gold trim, glowing runes, ornate readable UI.
- Production-quality authored character art; no circles, primitive-shape characters, or temporary geometric stand-ins presented as finished art.
- Character creation before the story: player chooses male/female presentation, name, class/path, and compatible appearance options.
- Opening story: the player arrives in a small town, finds Mathias (a battle mage) fighting enemies, helps him, then begins the WOA: Arcane Realm mystery.
- Mobile browser and desktop support are both required.
- Keep original source art separate from optimized game-ready sprites.

## Project structure
- `game/` — game scenes and scripts
- `assets/art-source/` — approved original reference images and source art
- `assets/sprites/` — transparent PNG sprites and animation sheets
- `assets/tilesets/` — world tiles and environment atlases
- `assets/effects/` — spell and combat effects
- `assets/ui/` — menus, frames, icons, portraits
- `docs/` — story, design, and asset specifications
- `web/` — browser build entry point and mobile shell
- `tests/` — validation and playtest checklist

## Art workflow
Upload approved artwork into `assets/art-source/` first. Do not crop, resize, or overwrite originals. Production sheets go into the matching `assets/` folder only after frame dimensions, transparency, pivots, and animation order are verified.

## Important
This is a clean foundation branch. The existing `main` branch remains untouched as a safety copy until the new foundation is reviewed and intentionally promoted. No artwork is claimed to be complete until actual image files have been added and checked in-game.
