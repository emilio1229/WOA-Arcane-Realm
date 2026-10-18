# Arcane Realm 3D Rebuild — Canonical Story and Gameplay Rules

## Canonical source

The WoA event bot repository `emilio1229/woa-event-bot` is the source of truth for story progression and RPG rules. The 3D browser game is a presentation and interaction layer; it must not invent a conflicting replacement story.

Primary story implementation:
- `src/arcane/story.ts` — chapter text, story choices, route/familiar state, encounters and boss progression.
- `src/arcane/store.ts` and the Prisma `arcaneQuestProgress` model — progression storage and persistence.
- Related battle, familiar, inventory, class, and reward modules in that repository are authoritative for their respective systems.

Before porting any chapter, inspect the current bot implementation rather than rewriting it from memory. Keep chapter titles, narrative text, choices, branching, encounters, familiar unlocks, and rewards aligned with the bot. If the bot story changes, update the 3D content mapping from that source.

## Character and NPC decisions

- Matthias is optional and is **not a required protagonist or gatekeeper**. Remove the existing Matthias-centered opening quest from the new 3D presentation.
- Do not delete bot story content merely because the old browser prototype used Matthias. Use the bot story's actual cast and locations.
- The player remains the central character. Preserve character class, robe/tradition choice, familiar companion, and progression data.
- NPCs should only be added to the 3D world when they have a role in the canonical bot story or a clearly marked optional world activity.

## 3D world and seed behavior

- Use a web-native 3D renderer for the deployed browser game and Discord Activity; the separate Godot prototype is a reference/prototype, not the live runtime.
- Save a world seed in player/world settings. Reloading the same saved seed reproduces the same terrain and prop placement.
- A deliberate **New World / Reroll Seed** action changes the seed. Do not randomize on every reload.
- Keep gameplay state (story chapter/step, choices, familiars, inventory, currency, combat rewards) separate from generated environment state. Changing the world seed must not reset player progression.
- Build connected regions with deterministic placement and mobile-friendly draw/texture budgets.

## Existing player data and compatibility

- Never silently reset player state during migration.
- Add a versioned adapter/migration for browser-local profile data if its schema changes.
- Treat the event bot's persisted quest state as canonical when an authenticated player is linked to Discord.
- If a browser-only player has progress not yet linked to the bot, preserve and migrate it rather than overwriting it.
- Where data conflicts, do not guess or silently overwrite; provide a reconciliation path.

## Asset rules

Approved candidates from `web/CC0-3D-ASSET-SOURCES.md`:
- Kenney Nature Kit
- Kenney Fantasy Town Kit
- ambientCG
- Poly Haven
- Tiny Treats Homely House, if its individual publisher page still confirms CC0

Only integrate files downloaded from original publisher pages with a verified no-attribution license. Commit a manifest recording exact source, pack, license, checked date, and files used. Optimize meshes and textures locally for mobile. A source shortlist is not proof of integration.

## Delivery order

1. Inventory the bot's canonical story, battle, familiar, inventory, and profile state.
2. Build a web-native 3D runtime and seeded region alongside the current game.
3. Integrate actual downloaded CC0 models and textures, with a manifest.
4. Add mobile touch controls, camera, interaction, collisions, and responsive layout.
5. Bridge 3D interactions to canonical bot story/progression without duplicating or resetting data.
6. Test build, mobile browser, Discord Activity viewport, and save compatibility.
7. Switch the default presentation to 3D.
8. Remove the old 2D renderer and only those 2D-only assets that no longer have references. Keep any story illustrations that remain useful in Codex or narrative UI.

## Truthful status at the time this plan was written

This document defines the required architecture; it does not claim the 3D runtime, assets, or story bridge are already implemented. The live browser entry point still uses Phaser, and the separate Godot prototype is not yet validated as the deployed game.
