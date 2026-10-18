# 3D Migration Contract — WOA Arcane Realm

This file records the implementation boundary for the move from the existing 2D Phaser presentation to a web-native 3D world suitable for a Discord Activity.

## User-approved direction

- The final player-facing game should be 3D, not pixel-art / 2D.
- The 3D environment should use free assets with licenses that do not require attribution.
- The world should be seed-based: same saved seed means the same world; a deliberate new-world action can create a different seed.
- The game must remain practical on phones and in an embedded Discord Activity.
- Preserve player profile, story/quest progress, inventory, familiars, combat/progression, and existing bot integration.

## Important migration rule

Do **not** delete the existing Phaser files or old visual assets until the 3D replacement has been validated against the acceptance checklist below. Deleting them first would risk losing functional systems and player-data compatibility before the replacement is ready. The goal is to remove the 2D presentation from the final game, not to destroy the underlying story/gameplay data or useful fallback during development.

## Implementation sequence

1. Create a web-native 3D renderer in a separate runtime module, isolated from the current Phaser scene.
2. Add seed and world-generation settings with stable deterministic placement.
3. Import the selected CC0 environment packs into committed asset directories, including license/source manifests. Do not rely on remote URLs as the only production copy.
4. Build one representative region with ground, forest edge, rocks, path, water, a landmark, and a small settlement.
5. Add touch movement, camera controls, collision, and mobile graphics settings.
6. Bridge 3D world events to existing story and profile state rather than replacing those systems.
7. Verify desktop and mobile behavior and production build before changing the main game entry point.
8. Switch the default game presentation to 3D only after the test region passes acceptance.
9. Remove the old 2D renderer and 2D-only presentation assets in a deliberate cleanup commit once no active feature depends on them.

## Acceptance checklist

- [ ] Loads as 3D in the existing web deployment path.
- [ ] Player can move using touch controls on an iPhone-sized viewport.
- [ ] Camera remains stable and readable in portrait and landscape.
- [ ] Same seed produces repeatable world layout.
- [ ] Changing the seed changes the layout.
- [ ] The region contains committed CC0 models/materials rather than only primitive placeholder meshes.
- [ ] Key routes and entrances remain traversable; props do not block them.
- [ ] Existing character/profile/story/familiar/inventory state is not reset.
- [ ] Game remains responsive in a Discord Activity-sized frame.
- [ ] Assets load without requiring a third-party model-host URL at runtime.
- [ ] Production build and deployed smoke test pass.
- [ ] Only then remove the old 2D renderer and assets that are no longer referenced.

## Current verified state (2026-10-17)

- The original Phaser browser game remains the active web entry point.
- A separate Godot 3D prototype exists under `godot-world-prototype/`, but is not the deployed game and has not yet been runtime-tested.
- `web/CC0-3D-ASSET-SOURCES.md` lists candidate asset publishers. Those packs have not yet been downloaded or integrated by this document's commit.
- No claim is made that the live game is already 3D or that its old 2D renderer has been removed.
