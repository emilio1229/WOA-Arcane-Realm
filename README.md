# WOA: Arcane Realm

**Current direction: 2D pixel-art RPG only.** The deployed browser game uses the lightweight 2D playtest in `playtest-2d/index.html`. The previous 3D/Godot build is not built, served, or loaded by the active deployment.

## Play

https://woa-arcane-realm-production.up.railway.app

## Current 2D prototype

- Character creation appears before gameplay.
- Players choose a male or female hero, enter a name, and select a starting path: Arcanist, Spellblade, or Warden.
- Pixel-style characters are drawn locally; no 3D models, external model downloads, or game APIs are used.
- Explore the village using mobile touch controls or desktop keyboard controls.
- Meet Mathias, the Battle Mage, and help fight hostile creatures with arcane magic.
- The HUD shows health and experience.

This is an early playtest. Progress is temporary, and richer sprite sheets, polished animations, deeper combat, persistent saves, quests, and additional areas remain future work.

## Controls

- **WASD / Arrow keys** — move
- **E** — interact / talk / close-range help
- **F** — cast arcane magic
- On mobile, use the on-screen directional pad and action buttons.

## Deployment

Railway serves the static 2D game through Nginx. The Dockerfile intentionally does not invoke Godot, compile a WebAssembly/WebGL export, or copy the old 3D project into the deployed website.

## Legacy files

Older Godot scripts, project files, and imported 3D assets are still present in the repository history/worktree as legacy material, but they are not part of the current build or active game. The live game is the 2D pixel-art prototype above.
