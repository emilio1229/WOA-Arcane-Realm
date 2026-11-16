# Arcane Artificer — internal asset creation and improvement pipeline

## Purpose

Arcane Artificer is the integrated backstage workflow for creating, editing, improving, validating, organizing, and delivering Arcane Realm assets. It is a development tool for Claude/AI and human creators—not a feature, NPC, crafting station, or menu inside the game.

It should help maintain a consistent art direction and reduce the time between an asset idea and a tested in-game result.

## Modules

### 1. World Builder
Create environment concepts, region layouts, sanctuary/town plans, portal destinations, landmarks, props, and set dressing. Maintain navigable spaces, gameplay readability, collision boundaries, scale references, and mobile camera framing. Produce asset lists and placement notes alongside visual concepts.

### 2. Character Forge
Create player character concepts, silhouettes, outfits, robe variants, equipment, and NPC designs. Preserve a consistent base character model/rig where practical. Support the five historical tradition color identities: Arcane, Ember, Frost, Verdant, Shadow. Prefer robe/appearance recoloring for traditions rather than unrelated body models.

### 3. Familiar Forge
Design familiar companions, silhouettes, personalities, animation sets, scale, and unlock presentation. Historical first familiar concept: Glimmer, associated with Keeper Moth and the Sleeping Portal onboarding seed. Define follow, idle, interaction, and ability behavior before producing final assets.

### 4. VFX Laboratory
Create and tune spell effects, projectile trails, impacts, status effects, portals, ambient magic, enemy telegraphs, and reward feedback. Ensure combat effects communicate timing, range, danger, and outcome. Provide low-cost/mobile variants and reduced-motion alternatives.

### 5. Interface Designer
Design HUD, inventory, quest journal, character screens, menus, touch controls, tooltips, notifications, and responsive layouts. Maintain a clean magical visual language without clutter. Check legibility, contrast, touch target size, and safe-area behavior.

### 6. Animation Studio
Define animation states, timing, transitions, hit reactions, locomotion, spell casting, familiar behavior, and NPC motion. Keep animation readable at the intended camera distance. Create lightweight/mobile-friendly variants when needed.

### 7. Asset Enhancement Lab
Inspect existing assets for consistency, resolution, silhouette, readability, lighting, color, artifacts, and technical suitability. Improve assets without changing approved identity or design intent. Track source and derivative versions; never overwrite originals without an explicit reason and backup.

### 8. Asset Library Manager
Maintain searchable asset IDs, categories, tags, source files, derivatives, previews, licenses, attribution, dimensions, formats, animation metadata, and engine import settings. Prevent duplicate/conflicting assets and broken references. Track approval status and intended use.

## Asset workflow

1. **Brief:** record purpose, gameplay context, camera distance, platform, dimensions, style, animation needs, and constraints.
2. **Reference:** gather approved references and record source/license/attribution.
3. **Concept:** create multiple clear directions where the design is not settled.
4. **Review:** compare against the art bible and gameplay readability.
5. **Produce:** create source artwork and optimized derivatives.
6. **Validate:** inspect dimensions, transparency, pivots, frame timing, file integrity, license, and performance.
7. **Integrate:** import into a test scene and verify scale, camera, lighting, animation, and mobile performance.
8. **Catalog:** register stable asset ID, version, source, metadata, and approval.
9. **Iterate:** retain originals and changelog; do not destroy source files.

## Art-direction rules

- Dimensional/isometric presentation; not a 2D pixel-art aesthetic.
- Strong silhouettes and readable values at mobile scale.
- Magical, atmospheric, polished, and coherent with WoA's wizard/warlock/witch identity.
- Purple/pink may be part of the WoA brand language, but world regions and spell schools should have distinct readable palettes.
- Keep player/NPC proportions and visual conventions consistent.
- Avoid overcomplicated VFX that obscure combat or reduce performance.
- Avoid generic placeholder art in a release-quality slice.

## Technical and licensing safeguards

- Record license and attribution for every third-party asset.
- Do not use unlicensed or unclear-rights art, fonts, audio, models, or textures.
- Keep high-resolution sources separate from optimized runtime derivatives.
- Use predictable naming and stable asset IDs.
- Validate texture sizes, compression, pivots, material complexity, animation frame counts, and memory budgets against target devices.
- Do not commit generated caches, temporary renders, or private reference material.
- Generated assets must still pass human review for consistency, quality, and rights.

## Future integration

The toolchain can eventually be connected to an asset manifest, preview gallery, automated validators, and engine import scripts. Those are developer workflows and must remain outside the player-facing game.
\n\n## Reusable Claude skill\n\nThe executable workflow is packaged as `.claude/skills/arcane-realm-asset-forge/SKILL.md`, with its art direction, production checklist, and brief templates in the adjacent `references/` directory. Invoke that skill for asset creation, enhancement, animation, visual audits, and technical integration. This skill operationalizes this document; it does not replace the repository's existing manifest or asset scripts.\n