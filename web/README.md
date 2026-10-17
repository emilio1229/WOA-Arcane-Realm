# WOA Arcane Realm — Phaser 4 web entry

This folder contains the isolated Phaser 4 browser preview for the Arcane Realm direction.

## Local preview
Open `index.html` in a modern browser with an internet connection. Phaser 4.2.1 is currently loaded from jsDelivr. For a more production-hardened build, vendor Phaser through a package-managed build pipeline so the game does not depend on a third-party CDN at runtime.

## Scene and story preview
- `index.html` contains the Phaser scene and responsive start/character-creation UI.
- `story-layer.js` adds the first interactive Mathias conversation, branching dialogue choices, a simple quest journal, magical choice effects, and a visual familiar toggle.
- The story layer is deliberately separate from the main HTML and is served beside the preview at `/phaser-preview/story-layer.js`.
- These are prototype-only story flags held in browser memory. Reloading loses them; they do not yet save to a server or Discord profile.
- The current dialogue is a new preview implementation, not a verified import of the full existing Godot story. Do not treat its quest or familiar as connected to production systems.

## Cloudflare Pages
This is a static site. In Cloudflare Pages, connect this repository and set:
- **Production branch:** `main`
- **Build command:** leave empty (no build step for this first static version)
- **Build output directory:** `web`
- **Root directory:** leave blank

After the first successful deployment, add your chosen subdomain under **Workers & Pages → your Pages project → Custom domains** and follow Cloudflare's DNS prompts. Do not remove existing DNS records until the Pages domain is verified.

## Discord Activity readiness
Hosting is only one part of a Discord Activity. The Discord Developer Portal still needs an Activity/Application configuration and URL mapping that points to the deployed HTTPS domain. The existing Discord bot's Arcane Realm button must then launch the Activity using the appropriate Discord SDK / launch flow.

## Important status / boundaries
- This is a **visual and interaction foundation**, not a complete production game.
- The start screen, Chronicles panel, responsive character creation, illustrated town preview, first dialogue branch, quest journal, and familiar visual toggle are implemented in the preview.
- The player name, class, dialogue choices, quest, and familiar toggle are currently held only in page memory. They are **not** saved to the Discord bot database or linked to existing player profiles.
- PvP/PvE, familiar combat, inventory, Sigils, progression, and existing saved data have **not** been wired into this entry point. Do not migrate or reset production player data as part of this UI milestone.
- The town and character preview use procedural shapes/symbols as temporary scaffolding, not final approved sprite art.
- Test the deployed site in desktop and mobile browsers before configuring the Activity URL mapping. Changes committed to the Railway-linked branch only appear after a successful deployment; this work does not itself confirm a live deployment.
