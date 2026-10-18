# 3D Migration Contract — WOA Arcane Realm

This file records the implementation boundary for the move from the existing 2D Phaser presentation to a web-native 3D world suitable for a Discord Activity.

## User-approved direction

- The final player-facing game should be 3D, not pixel-art / 2D.
- The 3D environment should use free assets with licenses that do not require attribution.
- The world should be seed-based: same saved seed means the same world; a deliberate new-world action can create a different seed.
- The game must remain practical on phones and in an embedded Discord Activity.
- Preserve player profile, story/quest progress, inventory, familiars, combat/progression, and existing bot integration.

## Important migration rule

The user has explicitly chosen to switch the player-facing experience to 3D now and does not want the 2D presentation. The production Docker entry point now serves `web/3d-preview.html` as `/`. Keep old source files in the repository temporarily only as recoverable code/data while the 3D runtime is being completed; they are no longer copied as the production homepage.

## Implementation sequence

1. Create a web-native 3D renderer in a separate runtime module, isolated from the current Phaser scene.
2. Add seed and world-generation settings with stable deterministic placement.
3. Import the selected CC0 environment packs into committed asset directories, including license/source manifests. Do not rely on remote URLs as the only production copy.
4. Build one representative region with ground, forest edge, rocks, path, water, a landmark, and a small settlement.
5. Add touch movement, camera controls, collision, and mobile graphics settings.
6. Bridge 3D world events to existing story and profile state rather than replacing those systems.
7. The default production entry point has been switched to the 3D runtime. Next, verify the Railway build and smoke-test desktop/mobile behavior.
8. Replace the prototype's primitive mesh blockout with locally committed, license-verified 3D assets; then connect live profile, combat, inventory, and familiar systems.
9. Remove the old 2D source files in a deliberate cleanup commit after confirming no shared gameplay/data feature still depends on them.

## Acceptance checklist

- [x] Production Docker entry point now serves the 3D page at `/` (deployment build/runtime still needs smoke testing).
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

- `Dockerfile` now copies `web/3d-preview.html` to the production `/index.html` and copies the canonical story manifest into `/data/`.
- The 3D page is a first playable prototype using Three.js from a CDN and procedural primitive meshes. It is not yet the finished art pass, and the CDN means runtime internet access is required for the renderer.
- Railway deployment and on-device smoke tests have not yet been confirmed.
- `web/CC0-3D-ASSET-SOURCES.md` lists candidate asset publishers. Those packs have not yet been downloaded or integrated by this document's commit.
- No claim is made that the live game is already 3D or that its old 2D renderer has been removed.
