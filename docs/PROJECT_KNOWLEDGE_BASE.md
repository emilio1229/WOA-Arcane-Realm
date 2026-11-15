# Arcane Realm — accumulated project knowledge

This document consolidates the known product direction and historical decisions so collaborators do not repeatedly lose context. It distinguishes confirmed user preferences from historical prototype notes and proposals.

## 1. Product identity

Arcane Realm is the fantasy RPG extension of the Wizards of Ark (WoA) community. Its identity should feel magical, welcoming, adventurous, and coherent with WoA's wizard/warlock/witch world.

- The game is a standalone project with its own repository and future runtime.
- Browser-first and mobile-friendly are core goals.
- A portal-connected world is the central world-navigation concept.
- The desired camera/look is higher-angle isometric and dimensional, not a 2D pixel-art game.
- Godot is explicitly not wanted.
- Phaser/TypeScript or another lightweight browser solution has been discussed, but the engine is not locked.
- The user prefers meaningful combat and active play over long reading sequences and button-heavy menus.

## 2. World and visual identity

### Known concepts
- Grand Portal: central hub and gateway to other areas.
- Sanctuary/town hub with recognizable buildings and useful NPCs.
- Five robe/tradition color identities previously explored: Arcane, Ember, Frost, Verdant, Shadow.
- Tradition identity should primarily be expressed through robe/appearance recoloring rather than entirely different character bodies.
- The overall tone is arcane, luminous, inviting, and polished; avoid clutter and generic placeholder presentation.

### Historical NPC concepts
These names appeared in a previous test-build concept and are not yet confirmed as final canon:
- Archmage Elowen
- Archivist Quill
- Keeper Moth
- Innkeeper Pip
- Merchant Zia
- Smith Brannoc
- Warden Sable

### Historical quest/familiar concept
“Sleeping Portal” was a prior onboarding quest concept: read the Quest Board, speak with Elowen, awaken the Grand Portal, defeat three Ember Wisps, return to claim the reward, and meet Keeper Moth to unlock Glimmer. Treat as a prototype seed, not immutable lore.

## 3. Core gameplay direction

Desired systems and themes:
- Character identity and progression.
- Exploration across connected regions through portals.
- Responsive real-time or otherwise engaging combat; exact combat model remains open.
- Spells and readable combat feedback.
- Enemy encounters that scale in challenge and reward.
- NPC interactions, quests, and discoverable lore.
- Familiars as companions/unlocks.
- Inventory and item ownership.
- XP, levels, and Sigils.
- Mobile touch controls plus desktop keyboard/mouse support.

The preferred loop is:
1. Enter or explore a region.
2. Discover a quest, NPC, objective, or encounter.
3. Fight, interact, or solve a meaningful objective.
4. Earn validated progress/rewards.
5. Return, claim, unlock, equip, or prepare for the next challenge.

Avoid a game that is mostly text, menus, passive timers, or clicking through dialogue.

## 4. Economy and WoA relationship

- Sigils are the intended game/Discord RPG currency concept.
- Sigil balances and transactions must eventually be protected against client tampering, duplication, replay, race conditions, and unauthorized grants.
- No ARK dinos or blueprints as rewards for the current game direction.
- Do not assume the ARK cluster's trading rules automatically define the RPG's item rules; document game-specific rules separately.
- The game should own authoritative character, inventory, battle, quest, familiar, and Sigil state if connected to a backend.
- Discord may provide identity/community integration later, but the client or Discord UI must never become the authority for valuable game state.
- No live player data or production integration until explicitly approved.

## 5. UI and interaction principles

- Mobile-first responsive layouts, with touch targets that are comfortable and clear.
- Desktop keyboard/mouse support.
- Historical keyboard concept: WASD/arrows movement, E/Enter interact, Q/Space cast, I inventory, Escape menu.
- Historical mobile concept: virtual joystick and dedicated interact/cast controls.
- Strong visual hierarchy; readable text; minimal clutter.
- Feedback for damage, hits, cooldowns, quest updates, loot, XP, and Sigils.
- Keep the game world visible as much as possible; do not bury play behind repeated menus.
- Accessibility: scalable UI, contrast, reduced-motion consideration, remappable controls where practical, and non-color-only status cues.

## 6. Prototype seed from earlier test build

A previous standalone concept had:
- Grand Portal title/loading experience.
- Character creation and five traditions.
- Isometric sanctuary with six buildings.
- Seven named NPC concepts.
- Sleeping Portal onboarding quest.
- Three Ember Wisps as first combat encounter.
- Arcane Bolt targeting nearest enemy in range.
- XP/levels, Sigil rewards, inventory/satchel.
- Glimmer familiar unlock.
- Local-only save with defensive validation and clamping.
- Explicit statement that the playtest was not connected to live player data.

The repository was inspected while being prepared and contained documentation only, not that prototype source. These notes preserve the concept; they do not claim the old prototype still exists.

## 7. Technology direction and constraints

- Browser game; mobile and desktop browser support.
- Phaser with TypeScript was one candidate.
- Phaser is a 2D HTML5 framework. It may be suitable for a carefully designed isometric/2.5D presentation, but not native full 3D by itself.
- If the required appearance is true 3D, evaluate a browser 3D rendering stack before committing.
- No Godot.
- Avoid choosing an engine solely because it is familiar; test it against camera, asset, mobile performance, input, and authoring requirements.
- Do not add unnecessary backend complexity before the first playable loop is proven.
- Do not mistake a standalone HTML mock-up for a maintainable game architecture.

## 8. Development collaboration

- This repo is the canonical home for game source, test builds, documentation, and game-specific assets.
- Website and event-bot repositories are separate and out of scope.
- The user wants Claude and ChatGPT to collaborate using shared documentation and a consistent engineering playbook.
- Claude should read CLAUDE.md and these docs before making changes.
- Keep a decision log; distinguish confirmed decisions, experiments, and proposals.
- Report real validation only. Do not claim browser testing, security, or deployment without doing it.

## 9. Internal development toolchain — not part of the game

The user requested a suite of reusable AI/developer skills and an integrated asset-creation/improvement system. These are backstage production tools. They must not be exposed as in-game mechanics, NPCs, shops, or player UI.

The Arcane Artificer pipeline is described in ARCANE_ARTIFICER_ASSET_PIPELINE.md. Security, persistence, and operations are described in ARCHITECTURE_SECURITY_BLUEPRINT.md and ENGINEERING_SKILLS_BLUEPRINT.md.
