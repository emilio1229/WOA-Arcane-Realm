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
- A hostile Frost Wisp now detects the player within its local aggro radius, pursues at a controlled speed, attacks at close range, has four health, and respawns after defeat. Player vitality is displayed in the HUD; taking damage produces a brief hit flash and camera shake, and reaching zero vitality returns the wizard to the sanctuary spawn with full vitality.
- The headless browser smoke test now includes the hostile Wisp combat loop and player damage checks.
- Ambient floating magic motes around the Sanctuary; touch controls now include both Interact and Cast.
- NPCs with names, idle bobbing, proximity detection, and E/Enter interaction.
- Responsive HUD and a contextual dialogue panel.
- Mobile virtual joystick, Interact, and Cast touch buttons.
- Glimmer now follows the player with eased trailing movement and a floating idle animation.
- Headless browser play test covers familiar following, spell damage, collision, NPC dialogue, and desktop/mobile controls.
- Reusable SVG asset scaffold generator (`npm run assets:new`) that registers stable IDs and refuses to overwrite existing artwork.
- No external game services, live player data, or production Discord authentication.

## Original asset pack

The repository now includes an original SVG asset library under `public/assets/`: five shared-silhouette tradition robes (Arcane, Ember, Frost, Verdant, Shadow) plus an Arcane casting pose, five distinct sanctuary building exteriors, three environment props (lantern, rune obelisk, crystal cluster), Glimmer, Verdant Sprite, Ember Wisp, Frost Wisp, Grand Portal, Arcane Bolt, Arcane Impact, Arcane Mote, and a Sigil icon. The Arcane wizard, Glimmer, Ember Wisp, portal, Arcane Bolt, impact burst, and ambient motes are integrated into the sanctuary scene. Stable IDs and provenance metadata live in `public/assets/manifest.json`; library rules are in `public/assets/README.md`. Run `npm run assets:validate` to check IDs, file paths, SVG dimensions, and safe inline-only content. Use `npm run assets:new -- --id <stable.id> --category <category> --name "Asset Name"` to scaffold and register new SVG source art.

## Deliberate limitations

- This is a playable foundation prototype, not the complete Stage 1 acceptance milestone.
- Original SVG character, familiar, creature, portal, spell, and UI assets now replace several initial primitives; building architecture, garden dressing, and some environment details remain procedural placeholders. All current art is prototype quality, not final release art. Wizard motion is procedural rather than a frame-based walk cycle; combat is a local prototype: the Ember Wisp is a stationary practice target with three health and timed respawn. There is no hostile enemy AI, progression-based cooldown system, or server authority; the short cast throttle only limits visual spam.
- Collision uses simple rectangular building footprints with axis-separated wall sliding; environment boundaries and pathing need refinement.
- Movement currently uses local client simulation. No server authority or persistent character save exists.
- The quest panel is informational only; no quest engine is implemented.
- Desktop and mobile-viewport controls, including familiar following and building wall-sliding, pass a headless Chromium play test in CI. Real-device touch feel, camera behavior across phones/tablets, and broader browser compatibility still require manual testing.
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
2. Expand combat with enemy telegraphs, varied attack patterns, player recovery, and more encounter types; implement authoritative validation before adding rewards.
3. Validate camera framing and resize behavior across phone, tablet, and desktop aspect ratios.
4. Evaluate the visual result against the dimensional/isometric target; if 2.5D is insufficient, stop expanding Phaser and evaluate a true 3D browser renderer.
5. Replace vector placeholders with original, licensed assets after the rendering direction is approved.
