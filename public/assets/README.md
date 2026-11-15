# Arcane Realm asset library

Original, editable SVG source assets for the Arcane Realm prototype.

## Rules

- Every asset has a stable ID in `manifest.json`.
- Keep original source art; create optimized derivatives rather than overwriting source files.
- Preserve the shared wizard silhouette and body proportions across the five tradition robes.
- Record source, license, dimensions, tags, intended use, and approval status.
- All assets in this initial pack are original in-repository SVG artwork. No external image or font artwork is embedded.
- Treat these as prototype art, not final release-approved character designs.
- Verify appearance, transparency, scaling, and mobile readability in the game before marking an asset production-approved.

## Initial pack

| Asset | Stable ID | Use |
|---|---|---|
| Arcane wizard | `character.wizard.arcane` | Player placeholder/reusable base tradition |
| Ember wizard | `character.wizard.ember` | NPC/tradition appearance |
| Frost wizard | `character.wizard.frost` | NPC/tradition appearance |
| Verdant wizard | `character.wizard.verdant` | NPC/tradition appearance |
| Shadow wizard | `character.wizard.shadow` | Future character customization |
| Glimmer | `familiar.glimmer` | First familiar concept |
| Ember Wisp | `creature.ember-wisp` | First enemy concept |
| Grand Portal | `environment.grand-portal` | Sanctuary landmark |
| Arcane Bolt | `vfx.arcane-bolt` | Spell effect icon/prototype |
| Sigil | `ui.sigil` | Currency/UI icon |

## Validation workflow

1. Check that each manifest path exists.
2. Parse each SVG as XML and verify declared dimensions.
3. Load the asset in Phaser at its intended display size.
4. Check alpha edges and silhouette against both light and dark backgrounds.
5. Review at the smallest target mobile size.
6. Keep source and runtime variants linked by stable ID.

The pack is integrated into the Sanctuary prototype: all five building exteriors, lanterns, rune obelisk, crystal cluster, Arcane wizard, Glimmer, Ember Wisp, and Grand Portal are loaded by the scene. Arcane Bolt and Sigil are catalogued for the next combat and HUD passes.
