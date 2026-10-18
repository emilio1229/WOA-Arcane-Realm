# Arcane Realm sprite production pipeline

This project adapts the *workflow ideas* from Chongdashu's MIT-licensed
[ai-pixel-snapped-game-sprites](https://github.com/chongdashu/ai-pixel-snapped-game-sprites)
and [ai-game-spritesheets](https://github.com/chongdashu/ai-game-spritesheets)
to the existing Phaser game. It does not copy their character artwork into WoA.

## Current state

- `assets/art-source/woa_arcane_realm_asset_starter.zip` remains the visual reference source.
- `web/src/arcane-art.ts` extracts transparent runtime previews from the concept panels.
- `web/runtime/arcane-art.js` is the browser bundle consumed by the game.
- Concept-panel crops are **single pose illustrations**, not authentic animation frames. Mathias's labeled poses can be used as temporary state illustrations, but must not be presented as a completed walk cycle.
- Runtime texture registration listens for Phaser's `addtexture-<key>` event before starting base64 decoding, avoiding a race on fast clients.

## Asset pipeline target

1. **Choose an identity anchor.** Approve one clear, full-body player or NPC view, with a defined palette, outfit, facing direction, and foot position.
2. **Generate poses from the same anchor.** Keep the silhouette, robe, staff, face, and proportions consistent. Create idle, walk, attack, cast, hurt, and defeat as separate animation sets. A walk loop should use actual distinct frames, not repeated copies of one pose.
3. **Recover foreground shapes.** Separate each character/effect from the sheet using foreground connected components or a known removable background. Do not crop by guessed equal-width columns when the source layout is irregular.
4. **Review before normalization.** Check every frame for cut-off accessories, leftover background, missing pixels, and unintended parts from adjacent panels.
5. **Normalize cells and anchors.** Pack frames into a documented atlas grid, use the same cell dimensions for each animation of a character, and align the feet to a common bottom-center anchor to reduce visual sliding.
6. **Keep edges crisp.** Use nearest-neighbor scaling for pixel-style art. Preserve alpha transparency and avoid global color-key removal that erases matching colors inside the subject.
7. **Describe atlases in metadata.** Record frame width/height, frame count, columns, playback rate, and anchor coordinates next to each sheet.
8. **Integrate and verify.** Load each atlas once, create named Phaser animations, and test idle-to-walk-to-action transitions in the town and combat scene at desktop and mobile sizes.

## Free-first policy

The current archive extraction and deterministic image processing run in the browser and do not need a paid AI API. The upstream sprite repositories describe optional hosted image/video generation services; those are not required for the existing game. Generate or commission new character frames only when that is available, then process and integrate the resulting files locally.

## License and attribution

The two sprite-pipeline repositories above state that their prompt templates, references, and spritesheets are MIT licensed. If any of their code is copied into this project in the future, preserve the upstream copyright/license notice and record the source. This document adapts workflow concepts; it does not redistribute upstream sprites or code.
