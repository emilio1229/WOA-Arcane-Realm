# Arcane Realm — Sandbox Direction

## Product promise
Arcane Realm is a persistent-feeling fantasy universe to explore freely, not a linear story level with a path to follow. The 3D world is the main experience; the Chronicle is an optional guide into the world's lore, not a gate that blocks exploration.

## Pillars
1. **Explore first:** players can roam, discover landmarks, enter settlements and wilderness, and choose what to do without being forced to advance the Chronicle.
2. **A world with identity:** build recognizable regions, silhouettes, architecture, magical weather, lighting, ambient life, and a distinct purple-arcane visual language. Replace placeholder primitives gradually with coherent art assets.
3. **Discoveries that matter:** points of interest, hidden ruins, shrines, portals, caches, and named locations should reveal lore, unlock places, and eventually grant progression.
4. **Player ownership:** name and class/path should become a saved character; later add inventory, equipment, familiars, gathering, crafting, building, and personal spaces.
5. **World seed as a world identity:** a seed should regenerate the same layout and landmark placements. It should not be mistaken for the whole game save; character progress and discoveries need separate persistence.
6. **Mobile and Discord friendly:** touch controls, readable UI, sensible performance limits, and a world that can later be embedded as a Discord Activity.

## World structure
- **The Veilgate (starting region):** fractured portal, ruined settlement, rune pool, first safe hub, and several visible landmarks to draw players outward.
- **Wild regions:** forest, highlands, haunted marsh, crystal caverns, and astral ruins. Each should have its own palette, terrain, hazards, creatures, and resources.
- **World destinations:** gates, towers, shrines, caves, and settlements provide reasons to travel and return.
- **Chronicle:** optional lore/story panel that can be hidden while exploring and resumed at any time.

## Implementation order
1. Stabilize world boot and mobile movement.
2. Make the first region feel intentional: cohesive terrain, a readable trail, strong landmark silhouettes, and actual 3D environment assets instead of piles of primitive geometry.
3. Add nearby discovery/interact prompts and a location journal.
4. Add a hideable exploration HUD and save character/world discoveries locally as a prototype.
5. Add gathering, inventory, familiars, and world activities.
6. Add additional biomes and persistence/server integration only after the single-player loop is enjoyable.

## Current prototype limits
The current page is an early 3D proof of concept. The world seed currently regenerates a procedural arrangement; character selection is not yet saved; story text is not connected to live bot progression; there is no multiplayer, crafting, building, or server-side persistence yet. These should be added in layers rather than pretending they already work.
