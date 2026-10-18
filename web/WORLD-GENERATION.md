# WOA Arcane Realm — Procedural World Foundation

## Direction

Build the world system before expanding the story map. The target is a controllable, seed-based fantasy world with a consistent hand-crafted art direction—not a random collection of primitive shapes. Preserve existing player, profile, story, inventory, familiar, and combat state while the environment evolves.

## World-generation principles

- **Seeded:** a world seed reproduces the same layout so a good world can be saved and revisited.
- **Configurable:** world settings control size, region weights, terrain, density, landmarks, and danger. Avoid hard-coded one-off placements.
- **Region-based:** generate a manageable region at a time and connect regions through paths, gates, rivers, caves, and transitions. This is mobile-friendlier than rendering an endless map at once.
- **Data before decoration:** first generate a terrain/biome layout, then paths and water, then landmarks, then scatterable props, then NPCs/resources/encounters.
- **Asset-driven:** trees, rocks, grass, cliffs, buildings, ruins, crystals, and props are real reusable assets. Geometry primitives may be used only as temporary debug markers.
- **Deterministic placement:** the same seed plus the same settings must create the same environment and keep collision, resource, and encounter placement stable.
- **Mobile budget:** keep visible object counts bounded, use simple materials and lighting, avoid expensive real-time shadows, and cull or unload distant regions.

## First playable region: Arcane Heartlands

A small, polished test region should establish the art style and world pipeline before the world grows:
- a traversable meadow and forest edge
- a stream or small pond
- a path that leads to a gate or settlement
- a magical landmark such as a crystal grove
- a few discoverable ruins
- clearings and blocked terrain so the world has readable navigation
- test NPC/resource/encounter spawn points

This is a prototype region, not the entire world.

## Generation pipeline

1. **Seed and settings:** world seed, region dimensions, biome distribution, object density, landmark frequency, and difficulty.
2. **Terrain map:** choose connected terrain/biome cells using weighted rules and adjacency constraints.
3. **Natural features:** establish elevations, watercourses, forest boundaries, cliffs, and passable routes.
4. **Landmarks:** place settlements, towers, shrines, caves, and ruins with spacing rules and valid access paths.
5. **Prop dressing:** scatter asset instances with biome-specific weights, rotation/scale variation, collision rules, and exclusion zones around paths and entrances.
6. **Gameplay spawns:** place resources, NPCs, enemies, treasure, and quest markers in valid locations.
7. **Validation:** check paths are connected, key landmarks are reachable, props do not block entrances, and generation stays within the frame/memory budget.
8. **Streaming and persistence:** load nearby region data, unload distant scenery, and save seed plus player changes such as opened chests, cleared encounters, and harvested nodes.

## Initial asset library to create

### Terrain and natural environment
- ground/grass and forest-floor materials or tiles
- dirt path, stone path, shoreline, shallow water, and stream pieces
- small/medium/large trees, plus dead/corrupted tree variants
- bushes, ferns, flowers, mushrooms, grass clumps, fallen logs
- small/medium/large rocks, boulders, cliff edges, and cliff corners
- water surface and simple river/pond edge pieces

### Magical and story landmarks
- crystal clusters in several sizes
- rune stones, shrines, broken pillars, ancient arches
- ruined walls, floor fragments, and doorway pieces
- wizard tower, cottage, settlement building modules, gate
- corrupted roots, dark crystals, breach/portal props

### Reusable gameplay props
- treasure chest, gatherable resource nodes, signs, lamps, campfire
- cave entrance, dungeon doorway, interactable shrine
- simple collision shapes and spawn markers (debug-only markers must not ship as art)

### Characters and creatures
- player character with tradition-specific robe/material tint variants
- Mathias as an independent NPC with his own world position and interaction radius
- familiars, wildlife, and enemy variants

## Visual asset rule

Use a coherent isometric/low-poly or pixel-inspired 3D style throughout. Each asset should have consistent scale, pivot/origin, collision footprint, and material palette. Do not stretch unrelated concept-sheet panels into fake sprite sheets or treat portraits as world models. Existing art can guide silhouettes, colors, and lore, but must be adapted into proper in-world assets before it is considered integrated.

## World-builder controls

The first useful editor/settings panel should expose:
- world seed (with a randomize button)
- region size
- biome/forest density
- rock and vegetation density
- water frequency
- landmark frequency
- corruption/magic intensity
- enemy/resource density
- regenerate preview
- lock/keep selected landmarks while regenerating the rest

Changing settings should preview a new deterministic world without erasing player/story data. World generation settings and player progression must be stored separately.

## Build order

1. Confirm the active renderer and existing scene boundaries before replacing anything.
2. Create a single environment asset standard and reusable asset library.
3. Build the Heartlands terrain/biome generator with a seed and adjustable settings.
4. Add real environmental assets and collision; remove placeholder geometry as each asset becomes ready.
5. Add paths, landmarks, NPC/resource/encounter placement.
6. Test touch movement, readability, load time, and memory on mobile.
7. Add region transitions and persistent world changes.
8. Expand biome/landmark library and connect more regions.

## Acceptance criteria for the first prototype

- Regenerating with the same seed produces the same layout.
- A different seed changes the layout while respecting the same settings.
- Density and biome controls visibly affect generation.
- The player can move through a connected playable area without props blocking key routes.
- Existing player/story data remains intact.
- Environment objects use the intended art assets rather than random colored boxes.
- Performance stays stable on a phone by limiting active objects and avoiding heavy effects.

## Current status

This document defines the implementation contract. It is not a claim that procedural generation or the listed assets have already been implemented. The current web scene needs a controlled environment-generation pass; do not call the world generator complete until it is connected to the playable scene and tested.
