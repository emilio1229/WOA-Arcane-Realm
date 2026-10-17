# WoA Arcane Realm Art Source

This directory is reserved for the original concept sheet and its reference crops. Keep source/reference art separate from production-ready sprites.

## Files to place here
- `arcane-realm-full-concept-sheet.png` — original full concept sheet.
- `panels/` — crops for player/classes, animations, portraits/UI, spell effects, Mathias, enemies, familiars, equipment, environment and branding.

## Production rule
Do not load the full concept sheet or panel crops as a Phaser animation atlas. They include borders, labels and multiple unrelated pieces of art. Draw/clean individual characters in Piskel, export transparent PNG sprite sheets with fixed frame dimensions, then place those in `web/assets/characters/` and register the animation frames in Phaser.

## Current status
Directory and integration instructions are committed. The binary concept sheet and crops have not been uploaded into this repository yet because this GitHub connection accepts text file contents but does not provide a binary-file upload operation. The starter ZIP is available in the ChatGPT conversation; upload its contents here to finish the source-art import.
