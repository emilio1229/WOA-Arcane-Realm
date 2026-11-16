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




## Sanctuary visual upgrade — first Asset Forge batch

- `environment.sanctuary-atmosphere` adds a moonlit ceremonial plaza ring, rune wayfinding, crystal garden beds, and layered perimeter groves as a transparent world-space layer.
- `environment.portal-rune-crown` adds a rotating metallic rune crown and luminous cardinal markers over the Grand Portal.
- Both are original editable SVG sources, registered in `manifest.json` and loaded by the Sanctuary scene. Their status is prototype-integrated pending in-game visual review.


## Realm arrival experience
- `ui.realm-title-backdrop` is the original 1600×900 SVG title-screen landscape, registered in the manifest.
- The title screen reports Phaser's real asset-loader progress and unlocks entry only after the Sanctuary scene finishes creating.
- The pause overlay is a player-facing control; asset workflows and developer tools remain backstage.


## Sanctuary town-life upgrade — Asset Forge batch

- `environment.sanctuary-townlife` adds paired merchant awnings, timber benches, warm street lanterns, pennants, a public noticeboard, a carved wayfinding marker, and small doorstep planters.
- The transparent 1800×1250 SVG layer is loaded beneath actors and building exteriors. Its props are kept to the outer edges and lower gathering areas so the central plaza and combat lanes remain readable.
- Original editable SVG source; no third-party artwork or fonts embedded. Integrated in the Phaser Sanctuary scene; visual review at gameplay scale remains pending.


## Sanctuary architectural detail overlays

Five original transparent SVG overlays enrich the existing Library, Familiar Sanctuary, Spell Academy, Merchant Hall, and Adventurer's Inn with carved trim, roof detailing, timber/stone framing, window accents, runic motifs, and warm light. The overlays are additive: the original building art and collision footprints are preserved. Each is 512×512 and registered as `building.detail.*`. Status remains `needs-review` until the in-game visual pass and target-scale checks are run.


## Sanctuary Moonwell Fountain

`environment.sanctuary-fountain` is an original 512×512 transparent landmark asset: a sculpted octagonal stone basin, layered water bowls, a faceted crystal crown, carved cardinal runes, and subtle water highlights. It replaces the temporary procedural ellipse stack in the center plaza. The scene adds a small number of low-cost animated glints around the crystal. Status: `needs-review` pending browser-scale art review.


## Sanctuary landmark interactions
The five main buildings now have proximity-based contextual interactions through the existing Interact/E control. Each landmark has its own action prompt and location lore. Nearby residents retain priority for direct conversation. These are exploration/lore interactions only; shops, training rewards, familiar adoption, and building interiors are not yet implemented.


## Town service interactions
The Spell Academy restores the practice Ember Wisp for repeatable combat training. The Adventurer's Inn restores player vitality as a safe-rest interaction. The Grand Library, Familiar Sanctuary, and Merchant Hall can be recorded as local discoveries; Merchant Hall is explicitly marked as not yet selling items. These local prototype services are not server-persistent.
