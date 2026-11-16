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
| Arcane wizard walk cycle | `character.wizard.arcane.walk` | Four-frame transparent locomotion sheet (256×320 cells at 8 fps) |
| Arcane wizard | `character.wizard.arcane` | Player idle pose/reusable base tradition |\n| Arcane wizard casting pose | `character.wizard.arcane.cast` | Temporary spell-casting pose with the same robe silhouette |
| Ember wizard | `character.wizard.ember` | NPC/tradition appearance |
| Frost wizard | `character.wizard.frost` | NPC/tradition appearance |
| Verdant wizard | `character.wizard.verdant` | NPC/tradition appearance |
| Shadow wizard | `character.wizard.shadow` | Future character customization |
| Glimmer | `familiar.glimmer` | First familiar concept |\n| Verdant Sprite | `familiar.verdant-sprite` | Verdant companion concept |
| Ember Wisp | `creature.ember-wisp` | First enemy concept |\n| Frost Wisp | `creature.frost-wisp` | Frost-aligned enemy concept |
| Grand Portal | `environment.grand-portal` | Sanctuary landmark |
| Arcane Bolt | `vfx.arcane-bolt` | Player spell projectile |\n| Arcane impact | `vfx.arcane-impact` | Spell impact burst |\n| Arcane mote | `vfx.arcane-mote` | Ambient floating magic particle |
| Sigil | `ui.sigil` | Currency/UI icon |
| Grand Library | `environment.building.grand-library` | Sanctuary building exterior |
| Familiar Sanctuary | `environment.building.familiar-sanctuary` | Sanctuary building exterior |
| Spell Academy | `environment.building.spell-academy` | Sanctuary building exterior |
| Merchant Hall | `environment.building.merchant-hall` | Sanctuary building exterior |
| Adventurer's Inn | `environment.building.adventurer-inn` | Sanctuary building exterior |
| Sanctuary lantern | `environment.prop.lantern` | Path lighting prop |
| Rune obelisk | `environment.prop.rune-obelisk` | Arcane landmark prop |
| Crystal cluster | `environment.prop.crystal-cluster` | Magical garden prop |
| Sanctuary ground | `environment.sanctuary-ground` | Isometric grass, flowering terrain, engraved plaza stones, and rune-inlaid sanctuary path |
| Sanctuary dressing | `environment.sanctuary-dressing` | Transparent world-space layer with corner groves, glowing mushrooms, flower clusters, rune wayfinding, and soft sanctuary light |
| Arcane burst sheet | `vfx.arcane-burst-sheet` | Six-frame, transparent spell impact animation (96×96 cells at 15 fps) |

## Validation workflow

1. Check that each manifest path exists.
2. Parse each SVG as XML and verify declared dimensions.
3. Load the asset in Phaser at its intended display size.
4. Check alpha edges and silhouette against both light and dark backgrounds.
5. Review at the smallest target mobile size.
6. Keep source and runtime variants linked by stable ID.

The sanctuary ground and transparent dressing layer are integrated into the Sanctuary prototype. The dressing adds corner groves, low shrubs, glowing mushrooms, flower clusters, stone inlays, and soft pools of light without blocking movement or mobile controls. The pack is integrated into the Sanctuary prototype: all five building exteriors, lanterns, rune obelisk, crystal cluster, Arcane wizard and walk cycle, Glimmer, Ember Wisp, and Grand Portal are loaded by the scene. Arcane Bolt, Arcane Impact, and Arcane Mote now power the first local spell-casting prototype and ambient magic layer. Sigil remains catalogued for the upcoming HUD/economy pass. Use Space or the mobile Cast control to launch the Arcane Bolt.

## Creating a new asset scaffold

Use the generator to reserve a stable ID, create an editable SVG source file, and register it in the manifest in one operation:

```bash
npm run assets:new -- --id creature.storm-wisp --category creature --name "Storm Wisp" --width 256 --height 256 --tags creature,enemy,storm,wisp
npm run assets:validate
```

Supported categories: `character`, `familiar`, `creature`, `environment`, `vfx`, `ui`, `building`, and `prop`. The generator rejects duplicate IDs/files and marks generated artwork as `scaffold`; replace the placeholder geometry and visually review it before integration. It never overwrites existing source art.


