# Foundation vertical slice — implementation status

## Rendering decision

The repository's current product notes intentionally leave the engine open: Phaser is a 2D framework and must prove it can deliver the desired dimensional/isometric look. This first implementation uses Phaser 3 as a **2.5D/isometric feasibility prototype**, not a claim of native 3D and not yet a final engine lock. Its scene is drawn with layered vector geometry so movement, framing, scale, and the visual direction can be assessed before investing in a full asset pipeline.

Official reference: https://docs.phaser.io/phaser/getting-started/installation

## Implemented in this slice

- Vite + TypeScript + Phaser 3 application shell.
- Responsive game canvas and camera follow.
- Isometric diamond ground presentation, plaza, gardens, fountain, and glowing portal with orbiting Sigil glyphs.
- Sanctuary buildings with depth layering and basic collision volumes.
- Controllable wizard with WASD/arrow movement, subtle idle/movement motion, and direction-aware facing.\n- First local spell-casting interaction: Space or the mobile Cast button launches an Arcane Bolt with an impact burst.\n- Ambient floating magic motes around the Sanctuary; touch controls now include both Interact and Cast.
- NPCs with names, idle bobbing, proximity detection, and E/Enter interaction.
- Responsive HUD and a contextual dialogue panel.
- Mobile virtual joystick and touch interaction button.
- Reusable SVG asset scaffold generator (`npm run assets:new`) that registers stable IDs and refuses to overwrite existing artwork.\n- No external game services, live player data, or production Discord authentication.

## Original asset pack

The repository now includes an original SVG asset library under `public/assets/`: five shared-silhouette tradition robes (Arcane, Ember, Frost, Verdant, Shadow), five distinct sanctuary building exteriors, three environment props (lantern, rune obelisk, crystal cluster), Glimmer, Ember Wisp, Grand Portal, Arcane Bolt, Arcane Impact, Arcane Mote, and a Sigil icon. The Arcane wizard, Glimmer, Ember Wisp, portal, Arcane Bolt, impact burst, and ambient motes are integrated into the sanctuary scene. Stable IDs and provenance metadata live in `public/assets/manifest.json`; library rules are in `public/assets/README.md`. Run `npm run assets:validate` to check IDs, file paths, SVG dimensions, and safe inline-only content. Use `npm run assets:new -- --id <stable.id> --category <category> --name "Asset Name"` to scaffold and register new SVG source art.

## Deliberate limitations

- This is a playable foundation prototype, not the complete Stage 1 acceptance milestone.
- Original SVG character, familiar, creature, portal, spell, and UI assets now replace several initial primitives; building architecture, garden dressing, and some environment details remain procedural placeholders. All current art is prototype quality, not final release art. Wizard motion is procedural rather than a frame-based walk cycle; combat is currently a local visual effect with no damage, enemy AI, cooldown system, or server authority.
- Collision uses simple rectangular building footprints; environment boundaries and pathing need refinement.
- Movement currently uses local client simulation. No server authority or persistent character save exists.
- The quest panel is informational only; no quest engine is implemented.
- Mobile controls are included but still require device/browser testing.
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

1. Install dependencies and run typecheck/build.
2. Browser-test movement, camera, collision, NPC interaction, spell visuals, and resize.
3. Test touch joystick and interaction on a real phone.
4. Evaluate the visual result against the dimensional/isometric target; if 2.5D is insufficient, stop expanding Phaser and evaluate a true 3D browser renderer.
5. Replace vector placeholders with original, licensed assets after the rendering direction is approved.
