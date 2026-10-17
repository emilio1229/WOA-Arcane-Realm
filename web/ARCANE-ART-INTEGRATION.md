# WoA Arcane Realm — Concept Art Integration

The generated concept sheet is the visual direction reference for the next art pass. It is not a directly loadable character atlas: it combines multiple panels, labels, portraits, effects, and differently sized figures.

## Target locations

- `web/assets/art-source/arcane-realm-concept-sheet.png` — full reference image (copy the generated concept sheet here)
- `web/assets/art-source/panels/` — organized reference crops from the starter pack
- `web/assets/characters/player/` — cleaned, transparent player spritesheets
- `web/assets/characters/mathias/` — Mathias spritesheets
- `web/assets/characters/enemies/` — enemy spritesheets
- `web/assets/characters/familiars/` — familiar spritesheets
- `web/assets/effects/` — spell and impact effects
- `web/assets/ui/equipment/` — item icons

## First playable sprite contract

Create these as individual transparent PNGs, each with a consistent frame size within its animation:

| Asset | Initial frames | Notes |
|---|---:|---|
| `player-idle.png` | 4 | Stable silhouette, subtle robe/staff motion |
| `player-walk.png` | 6 | Feet remain aligned |
| `player-run.png` | 6 | Same character proportions |
| `player-attack.png` | 6 | Weapon motion and readable impact |
| `player-cast.png` | 8 | Staff/hand gesture; effects may be separate |
| `portal-loop.png` | 8 | Separate transparent effect |

Start with 32x48 pixels only if the wizard fits clearly; otherwise choose a larger frame (for example 48x64) and keep it consistent across player animations. Export PNG at 1x and document frame dimensions. Avoid resampling the concept sheet into a fake sprite atlas.

## Phaser integration checklist

1. Copy the concept sheet and reference crops into the paths above.
2. Add cleaned sprite sheets under `web/assets/characters/`.
3. In Phaser preload, load each sheet with its exact frame width/height.
4. Register named animations (idle, walk, run, attack, cast) and switch them based on the existing player state.
5. Keep story, profile, inventory, familiar, and PvP/PvE state untouched.
6. Test keyboard and mobile controls and verify no animation frame contains labels, panel borders, or neighboring characters.

## Status

This document establishes the asset contract and intended locations. The reference image and reference crops still need to be copied into this repository from the conversation asset pack; this text-only GitHub connection cannot transfer local binary image bytes directly. No playable sprite animation should be considered integrated until actual transparent frame sheets exist and are loaded by the game.
