# WOA Arcane Realm

A standalone, browser-first fantasy RPG prototype for the Wizards of Ark (WoA) community.

**This repository is the only home for Arcane Realm game code, test builds, game documentation, and game assets.** The WoA website and event-bot repositories are separate projects and must not be modified as part of Arcane Realm work.

## Project direction

Arcane Realm is intended to become a mobile-friendly, browser-playable, higher-angle isometric and dimensional fantasy RPG. Godot is explicitly excluded. Phaser is currently used for a 2.5D feasibility prototype, not claimed as native 3D or permanently locked as the final renderer. If the visual target requires true 3D, evaluate a browser 3D renderer before expanding the prototype.

## Start here

- `docs/PROJECT_KNOWLEDGE_BASE.md` — accumulated product direction and decisions.
- `docs/PROTOTYPE_BRIEF.md` — confirmed context, prototype seeds, and unresolved choices.
- `docs/FOUNDATION_VERTICAL_SLICE.md` — current playable foundation and honest implementation status.
- `docs/ENGINEERING_SKILLS_BLUEPRINT.md` — internal engineering playbook.
- `docs/ARCANE_ARTIFICER_ASSET_PIPELINE.md` — internal asset production workflow.
- `docs/ARCHITECTURE_SECURITY_BLUEPRINT.md` — target-state security and operations.

## Run locally

Requires Node.js 22+ and npm.

```bash
npm install
npm run dev
```

Open the URL printed by Vite (normally http://localhost:5173).

```bash
npm run typecheck
npm run build
npm run preview
```

## Current foundation

The first playable foundation has been added: isometric-style sanctuary environment, camera follow, keyboard movement, building collision footprints, NPCs and proximity interaction, HUD, and mobile joystick/touch interaction. Art is currently procedural placeholder geometry. This slice has not yet been browser- or device-tested in this environment; see `docs/FOUNDATION_VERTICAL_SLICE.md` for limitations and next validation steps.

## Repository boundaries

- Keep all Arcane Realm game work here.
- Do not modify `wizardsofark-website` or `woa-event-bot`.
- Do not deploy, publish, connect production services, or use live player data without explicit approval.
- Preserve existing work and make focused, reviewable changes.
- Never commit credentials, private player data, generated caches, or unlicensed assets.
- Internal developer/AI tools are not player-facing game features.

## Technical reference

- https://docs.phaser.io/ — Phaser documentation and installation guidance.
