# Foundation vertical slice — implementation status

## Rendering decision

The repository's current product notes intentionally leave the engine open: Phaser is a 2D framework and must prove it can deliver the desired dimensional/isometric look. This first implementation uses Phaser 3 as a **2.5D/isometric feasibility prototype**, not a claim of native 3D and not yet a final engine lock. Its scene is drawn with layered vector geometry so movement, framing, scale, and the visual direction can be assessed before investing in a full asset pipeline.

Official reference: https://docs.phaser.io/phaser/getting-started/installation

## Implemented in this slice

- Vite + TypeScript + Phaser 3 application shell.
- Responsive game canvas and camera follow.
- Isometric diamond ground presentation, plaza, gardens, fountain, and glowing portal with orbiting Sigil glyphs.
- Sanctuary buildings with depth layering and basic collision volumes.
- Controllable wizard with WASD/arrow movement, subtle idle/movement motion, and direction-aware facing.
- First local spell-casting interaction: Space or the mobile Cast button launches an Arcane Bolt with an impact burst and a short local cast throttle.
- Aimed Arcane Bolts can damage the three-health Ember Wisp practice target; its health bar updates, it is briefly dispelled at zero health, and it respawns after a short delay.
- A hostile Frost Wisp detects the player within its local aggro radius, pauses during a readable 700ms melee windup, and only lands the strike if the player remains inside its contact radius; moving clear can cancel or evade the attack. It has four health and respawns after defeat.
- Player vitality is displayed in the HUD; taking damage produces a brief hit flash and camera shake plus a 650ms recovery window shown in the HUD, preventing overlapping hits from draining multiple hearts at once. Reaching zero vitality returns the wizard to the sanctuary spawn with full vitality.
- A player dodge/evade burst is available through Shift on desktop and a dedicated mobile button. It moves in the current movement direction (or the last facing direction), lasts 210ms, grants 310ms of local invulnerability, and has a 1,250ms cooldown shown in the HUD.
- The Ember Sentry is a ranged enemy prototype. It holds its ground, marks the player's position during a 620ms warning, then launches a slow fire orb toward that location. The orb checks the player's actual position on impact, so movement and a well-timed dodge can avoid it. The Sentry has five health and can be damaged by Arcane Bolts.
- The headless browser smoke test covers Frost Wisp telegraph escape and successful hits, post-hit recovery and overlapping-hit protection, dodge movement/cooldown, an Ember Sentry fire-orb dodge, Sentry damage, and mobile dodge activation.
- Ambient floating magic motes around the Sanctuary; touch controls now include both Interact and Cast.
- NPCs with names, idle bobbing, proximity detection, and E/Enter interaction.
- Responsive HUD and a contextual dialogue panel.
- Mobile virtual joystick, Interact, and Cast touch buttons.
- Glimmer now follows the player with eased trailing movement and a floating idle animation.
- Headless browser play test covers familiar following, spell damage, collision, NPC dialogue, and desktop/mobile controls.
- Reusable SVG asset scaffold generator (`npm run assets:new`) that registers stable IDs and refuses to overwrite existing artwork.
- No external game services, live player data, or production Discord authentication.

## Original asset pack

The repository now includes an original SVG asset library under `public/assets/`: five shared-silhouette tradition robes (Arcane, Ember, Frost, Verdant, Shadow), Arcane casting and four-frame walk poses, five distinct sanctuary building exteriors, three environment props (lantern, rune obelisk, crystal cluster), Glimmer, Verdant Sprite, Ember Wisp, Frost Wisp, Grand Portal, Arcane Bolt, Arcane Impact, Arcane Mote, and a Sigil icon. The Arcane wizard and walk cycle, Glimmer, Ember Wisp, portal, Arcane Bolt, impact burst, and ambient motes are integrated into the sanctuary scene. Stable IDs and provenance metadata live in `public/assets/manifest.json`; library rules are in `public/assets/README.md`. Run `npm run assets:validate` to check IDs, file paths, SVG dimensions, and safe inline-only content. Use `npm run assets:new -- --id <stable.id> --category <category> --name "Asset Name"` to scaffold and register new SVG source art.

## Deliberate limitations

- This is a playable foundation prototype, not the complete Stage 1 acceptance milestone.
- Original SVG character, familiar, creature, portal, spell, and UI assets now replace several initial primitives; the Arcane player has a four-frame walk cycle, while NPC idle motion remains procedural. Building architecture, garden dressing, and some environment details still use procedural placeholders. All current art is prototype quality, not final release art. Combat remains local prototype logic: Frost Wisp pursuit and Ember Sentry projectiles are simple scripted behaviors, and player health, dodge cooldowns, and enemy health are not server-authoritative or persistent.
- Collision uses simple rectangular building footprints with axis-separated wall sliding; environment boundaries and pathing need refinement.
- Movement currently uses local client simulation. No server authority or persistent character save exists.
- The quest panel is informational only; no quest engine is implemented.
- Desktop and mobile-viewport controls, including familiar following, building wall-sliding, dodge input, and combat interactions, are covered by the headless Chromium play test and CI workflow. Real-device touch feel, camera behavior across phones/tablets, and broader browser compatibility still require manual testing.
- No backend, database, multiplayer, Discord Activity, or Sigil integration is included.

## Run locally

Requires Node.js 22+ and npm.

```bash
npm install
npm run dev
```

Open the local URL printed by Vite (normally http://localhost:5173).

```bash
npm run typecheck
npm run build
npm run preview
```

## Next validation

1. Test touch joystick and interaction on a real phone.
2. Add a third enemy pattern and more deliberate encounter pacing; implement server-authoritative combat and player-state validation before adding rewards or progression.
3. Validate camera framing and resize behavior across phone, tablet, and desktop aspect ratios.
4. Evaluate the visual result against the dimensional/isometric target; if 2.5D is insufficient, stop expanding Phaser and evaluate a true 3D browser renderer.
5. Replace vector placeholders with original, licensed assets after the rendering direction is approved.


## Asset Forge visual pass — sanctuary atmosphere

The first `arcane-realm-asset-forge` implementation batch adds two original SVG layers: `environment.sanctuary-atmosphere` (moonlit plaza engraving, rune markers, crystal beds, and framing groves) and `environment.portal-rune-crown` (ornamental portal ring and cardinal runes). Both are registered in `public/assets/manifest.json`, loaded by `src/main.ts`, and used as transparent layers so the existing ground, collision, movement, and combat systems remain unchanged. The HUD and overlay panels also receive a restrained glass-and-metal visual polish in `src/style.css`. These changes are marked prototype-integrated; a real browser visual pass and mobile-device review remain required before calling them validated.


## Realm arrival, title screen, and GameUI pass
- Added an original 1600×900 title-screen landscape registered as `ui.realm-title-backdrop`.
- The cinematic arrival screen reports real Phaser asset-loader progress and enables entry after the Sanctuary scene completes creation.
- Added an in-game pause overlay with Resume and desktop control reminders. The menu button and Escape key pause/resume the Sanctuary scene; Escape closes open dialogue first.
- Added responsive mobile layouts, focus-visible keyboard styling, and reduced-motion support. Existing combat, movement, NPC, and mobile control logic is unchanged.
- Browser smoke coverage for title-screen entry and pause/resume is added. CI must run before this change is considered validated; no real-device visual review has been performed.


## Player interface follow-up
- Expanded the pause surface into a responsive Wayfarer's Compendium with Character, Journal, World, and Controls sections. Values shown are limited to the current local prototype (Wayfarer, level 1, Arcane tradition, Glimmer, current vitality, one known spell, Sanctuary).
- The journal labels the Sanctuary prompt as exploration guidance, not a reward-bearing quest. The menu explicitly notes that progress is not saved.
- Added a desktop Arcane Bolt quickbar button and a live local cooldown label; Space and 1 both cast the existing spell. Mobile continues to use the dedicated Cast touch button.
- Browser smoke coverage now opens multiple menu sections, returns to play, and activates the spell quickbar. This coverage is authored but has not yet been run in this environment.


## Character creation foundation
- Added a character-creation screen before entering the playable prototype. It captures a character name, masculine/feminine presentation preference, one of the six established wizard traditions, one of the three combat disciplines (Arcanist, Spellblade, Warden), and a custom magic color.
- Added six recolored wizard walk cycles and matching cast poses in shared sprite sheets. Tradition selection changes the robe palette and matching walk/cast artwork while preserving the existing wizard silhouette; magic color separately tints the spell projectile.
- Choices persist locally in this browser. This is not yet account-backed or synchronized with Discord, and the current Sanctuary scene remains a development scene rather than the canonical Gloamwick story opening.
- Gender presentation is captured as a character-creation choice, but distinct male/female body and hair artwork is still outstanding. The opening village and Matthias encounter are also not yet restored in this build.


## Sanctuary town-life pass

The Asset Forge town-life pass adds a transparent, original SVG layer with market awnings, benches, warm street lanterns, pennants, a public noticeboard, wayfinding, and doorstep planters. The layer is registered in the asset manifest and loaded beneath actors/building exteriors. Placement favors the outer edges and lower gathering spaces to preserve the central plaza and existing combat lanes. This is an additive environmental dressing pass; the current map remains the Sanctuary prototype rather than the canonical Gloamwick story opening. Visual review in a running browser remains pending.


## Movement and tradition fidelity follow-up
- Normalized all non-zero movement input after the isometric projection so cardinal and diagonal input use the same world-space speed.
- Added frame-rate-independent acceleration/deceleration and reduced the movement delta clamp to 33.3ms to limit large steps after slow frames.
- Collision resolution now removes velocity only on the blocked axis, preserving reliable wall sliding without accumulating blocked movement.
- Walking animation now reflects actual resolved movement, not merely held input; idle frames are selected from the active tradition's sprite-sheet row.
- Arcane Bolt impact bursts inherit the chosen magic color as well as the projectile.
- Browser smoke coverage now checks all six idle robe rows and compares cardinal/diagonal travel distance. These tests are authored but not yet run in this environment.


## Sanctuary architecture detail pass

Added five original 512×512 transparent SVG overlay assets for the Grand Library, Familiar Sanctuary, Spell Academy, Merchant Hall, and Adventurer's Inn. They add carved stone/wood framing, roof and cornice accents, window mullions, crest/rune work, and localized warm or elemental light. Existing base building SVGs and collision footprints are retained; overlays are layered directly above their matching building textures. Manifest status is `needs-review` pending live browser visual review and mobile-scale inspection.


## Sanctuary Moonwell landmark

Added `environment.sanctuary-fountain`, a 512×512 original SVG landmark with layered carved stonework, a reflective water basin, a faceted crystal crown, and engraved runes. The previous procedural fountain ellipse stack is replaced with the asset, with a restrained pulse and five small ambient glints. Manifest status is `needs-review` pending visual inspection in a running game and mobile viewports.
