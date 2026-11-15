# WOA Arcane Realm

A standalone, browser-first fantasy RPG prototype for the Wizards of Ark (WoA) community.

**This repository is the only home for Arcane Realm game code, test builds, game documentation, and game assets.** The WoA website and event-bot repositories are separate projects and must not be modified as part of Arcane Realm work.

## Project direction

Arcane Realm is intended to become a mobile-friendly, browser-playable, higher-angle isometric fantasy RPG with a portal-connected world, memorable NPCs, combat, quests, familiars, spells, and persistent character progression.

The visual target is a clean, atmospheric, dimensional/isometric presentation—not a 2D pixel-art game. Godot is explicitly not wanted. Phaser with TypeScript or another lightweight browser technology has been considered, but the final renderer/engine is not yet locked. Phaser is a 2D framework, so it must not be represented as native 3D; any 2.5D/isometric approach must be evaluated against the visual requirement before adoption.

## Start here

1. docs/PROJECT_KNOWLEDGE_BASE.md — accumulated direction, gameplay, world, UX, and boundaries.
2. docs/PROTOTYPE_BRIEF.md — confirmed decisions, prior test-build concept, and unresolved choices.
3. docs/ENGINEERING_SKILLS_BLUEPRINT.md — internal development skills and operational safeguards.
4. docs/ARCANE_ARTIFICER_ASSET_PIPELINE.md — internal asset creation and improvement workflow.
5. docs/ARCHITECTURE_SECURITY_BLUEPRINT.md — future authoritative services, data integrity, security, and recovery.

## Repository rules

- Keep all Arcane Realm work in this repository.
- Do not modify wizardsofark-website or woa-event-bot.
- Do not deploy, publish, or connect live player data without explicit approval.
- Preserve existing work; make focused, reviewable commits.
- Treat ideas and historical prototype notes as design context, not proof that a working implementation exists.
- Keep internal developer/AI tools out of the player-facing game.
- Never commit credentials, private player data, generated caches, or unlicensed assets.

## Current status

This repository began as documentation only. No runnable game source, engine configuration, art assets, or build pipeline has been verified yet. The next implementation milestone is to settle the rendering approach against the isometric visual requirement, then build one small, playable, testable vertical slice.

## External technical reference

- https://docs.phaser.io/ — Phaser documentation. Phaser is 2D; confirm that an isometric/2.5D implementation meets the intended look before choosing it.
