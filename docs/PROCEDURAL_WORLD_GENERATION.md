# Procedural World Generation Plan

## Design decisions

- **World shape:** one large, continuous overworld. The current playable map uses a 1,200 × 1,200 metre ground plane, with the existing story spaces preserved around the starting town and Sigil Sanctuary.
- **Content style:** handcrafted story locations, deterministic seeded wilderness placement, and separately generated dungeon layouts.
- **Persistence:** the overworld seed is stored with the player's save, so the wilderness layout stays stable between sessions. Dungeon runs get a fresh seed when entered; the current seed is saved with the rest of the profile.
- **Art direction:** reuse the project's existing haunted blackwood tree asset, with procedural rocks, arcane shards, glowing landmarks, and violet dungeon lighting.
- **Performance:** keep the first pass intentionally lightweight and use a bounded number of wilderness props. If the world grows further, migrate to chunk-based loading and MultiMeshInstance3D for repeated foliage.

## Implemented in the current pass

1. Expanded the ground and collision surface to 1,200 × 1,200 metres.
2. Kept the starting town, Mathias encounter, three Sigil shrines, sanctuary gate, and First Trial as fixed story content.
3. Added a seeded wilderness scatter outside the protected story area, using the existing blackwood tree model and procedural rock/shard variants.
4. Added four stable, glowing navigation landmarks: The Hollow Crown, Ashen Watch, Moonwell, and The Fallen Archive.
5. Added The Shifting Hollow, an overworld dungeon entrance. Press **E** nearby to generate a winding set of chambers and arcane-lit markers; find the violet exit and press **E** to return to the same overworld position.
6. Stored the world seed and latest dungeon seed in the existing `user://arcane_realm_save.json` save alongside story progress.
7. Kept the scene file minimal; the existing main script constructs the world so model instances are not duplicated at the origin.

## Generation and save rules

- The overworld seed defaults to `730241` for existing/new profiles and is read before world construction. The generator uses a local `RandomNumberGenerator`, so procedural placement does not depend on unrelated random calls.
- Story-critical locations near the spawn are excluded from the random scatter.
- Each dungeon entry gets a new seed and chamber arrangement. The overworld seed and story flags remain unchanged when the player returns.
- The dungeon currently acts as a repeatable exploration space, not a completed combat/loot dungeon. Its room geometry and decorative markers are generated, but enemy encounters, loot tables, and saveable dungeon completion are future work.

## Next phases

### Phase 2 — Biomes and traversal
- Add distinct forest, ashland, moonlit marsh, and ruined highland regions.
- Add authored roads between landmarks and use terrain height/noise rather than a single flat ground plane.
- Add distance-based prop density and chunk activation to keep browser performance healthy.

### Phase 3 — Dungeon gameplay
- Give chambers gameplay roles (combat, puzzle, treasure, sanctuary), spawn enemies and rewards from the dungeon seed, and add an end-of-run summary.
- Persist discovered landmarks, collected overworld resources, and dungeon reward claims.
- Add a clear return/respawn safeguard so leaving a dungeon is always possible.

### Phase 4 — World tools
- Expose a world seed in settings for reproducible worlds.
- Add a debug overlay for seed, coordinates, biome, and dungeon chamber index.
- Add automated headless Godot validation for scene parsing and script errors before the web export smoke test.
