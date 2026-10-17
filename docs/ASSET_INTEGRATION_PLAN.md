# Arcane Realm — External 2D Asset Integration Plan

This document is the source-of-truth checklist for bringing third-party 2D art into the game. A pack is not considered integrated until the actual files are committed, the browser scene loads them, and a visual smoke test confirms they render.

## Selected sources

- **Kenney Isometric assets** — candidate foundation for consistent isometric environment tiles and props.
- **Kenney Roguelike/RPG Pack** — candidate source for terrain, buildings, interiors, and general RPG props.
- **Kenney Tiny Town / Sketch Town** — candidate source for town buildings and decoration.
- **Tiddybub/2d-assets** — discovery catalog only; select individual packs from their original sources rather than treating the catalog itself as an asset pack.

## License gate

Before importing any individual pack:
1. Follow its link to the original creator's distribution page.
2. Verify the license for that exact pack (prefer CC0/public domain; no attribution required).
3. Record the source URL, license, and verification date in `ASSET_LICENSES.md`.
4. Do not assume that every item listed in a collection has the same license.
5. Do not import files with unclear licensing.

## Integration rules

- Preserve the existing 2D browser game and mobile controls.
- Keep original source files in `assets/art-source/` when appropriate; place optimized runtime atlases and sprites in `assets/tilesets/` or `assets/sprites/`.
- Establish one consistent tile size and isometric grid before populating the world.
- Add tile/object collision metadata and use ground-anchor points for character depth sorting.
- Use actual imported art in the rendered scene; CSS/shape placeholders are not a substitute for completed asset integration.
- Keep custom WOA characters (including Mathias and the Archivist) visually distinct from generic asset-pack characters.

## Acceptance checklist

- [ ] Actual CC0 asset files are committed to the repository.
- [ ] Browser scene loads the imported assets without missing-file errors.
- [ ] Outer Ward visibly uses the new terrain, paths, buildings, and props.
- [ ] Player/NPC ground anchors sort correctly when walking in front of and behind one another.
- [ ] Solid objects block movement; decorative objects can be configured independently.
- [ ] Mobile viewport and touch controls remain usable.
- [ ] License/source record is complete.
- [ ] Build and visual smoke test pass.

## Current status

This checklist is a plan, not evidence that external image files have been imported. Do not mark the work complete until the acceptance checks above have been verified.
