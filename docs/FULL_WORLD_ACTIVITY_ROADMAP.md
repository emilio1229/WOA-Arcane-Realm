# Arcane Realm — Full World and Discord Activity Delivery Plan

## Product goal

Deliver one persistent Arcane Realm experience entered through the existing Discord `/realm` panel and launched as a Discord Activity. The browser game must not become a disconnected second game: character identity, story progress, inventory, Sigils, familiars, PvE/PvP results, and party state must use the same trusted player records as the existing Arcane Realm systems.

## Current state (important)

- `web/index.html` is a Phaser browser preview for the Outer Ward, not yet a fully integrated Discord Activity.
- `web/story-data.js` and `web/canonical-story.js` contain narrative/prototype progression. The web preview does not yet prove that every story chapter is playable or saved against the existing bot/database records.
- `web/player-systems.js` uses browser local storage for preview profile state. That is not suitable as the authority for shared progression, purchases, rewards, or PvP.
- `activity-preview/index.html` is a visual Activity hub prototype with sample values; it is not authenticated or wired to live records.
- `docs/DISCORD_ACTIVITY_INTEGRATION.md` describes the planned SDK/OAuth/server integration.
- Keep existing `/realm` and `/council` behavior intact during implementation. Do not replace production data or create a duplicate progression database.

## Delivery phases

### 1. Finish the playable single-player foundation
- Integrate and render the imported isometric spritesheet; continue adding compatible terrain/buildings and preserve source/license records.
- Complete the mobile/desktop HUD: movement, attack, class spell, familiar action, interact, health/mana, quest objective, inventory, and menu/music toggle.
- Make combat actions real encounter actions rather than explanatory pop-ups. Validate mana, turn state, range, damage, and encounter completion.
- Make the opening sequence playable from character creation through Mathias's first encounter and the first story objective.
- Add smoke checks for script loading, narrow mobile layouts, and controls.

### 2. Make the complete story a real quest campaign
- Audit the authoritative story in the existing Arcane Realm/Discord bot before expanding browser-only story text.
- Build a chapter/quest manifest with stable IDs, prerequisites, branching choices, encounter IDs, rewards, and completion rules.
- Implement chapters incrementally with NPC conversations, exploration objectives, battles, discoveries, and chapter transitions.
- Save quest state through the server. A refresh or new device must not reset a player's story.
- Preserve shared canon while allowing optional quests and meaningful player choices; avoid silently inventing incompatible class names, stats, rewards, or lore.

### 3. Connect it as a real Discord Activity
- Bootstrap the Discord Embedded App SDK and configure the Discord application, Activity URL mapping, and OAuth/session flow.
- Verify the player's Discord identity server-side; client-provided IDs are not authorization.
- Add authenticated server endpoints that map the Activity to existing ArcaneCharacter, ArcaneQuestProgress, familiar, inventory, and Sigil records.
- Keep bot tokens and secrets server-side only.
- Launch from the existing `/realm` Arcane Realm entrance. The Activity is the visual game client for the same realm, not a separate progression silo.

### 4. Add co-op and PvP after shared identity/state works
- Start with party/invite/join flows, shared quest instances, and server-saved party progress.
- Add synchronized player positions and encounter state through a server-authoritative room/session layer (WebSocket or equivalent).
- Add opt-in PvP arenas/matches after PvE and rewards are server-authoritative. Validate turn/actions, cooldowns, mana, rewards, and disconnects on the server.
- Never trust client-reported damage, currency, purchases, quest completion, or PvP outcomes.
- Add presence, reconnect handling, party ownership, and basic abuse/rate-limit controls.

### 5. Test and roll out safely
- Use a Discord development application first and test on iPhone, desktop, and multiple simultaneous players.
- Keep visual prototype changes separate from production data changes; preserve a rollback path.
- Deploy only after the Activity launch, identity mapping, save/load, encounter flow, and mobile layout pass end-to-end tests.

## Definition of done

- `/realm` opens the existing entrance and launches the Activity without removing current bot fallback interactions.
- The same player sees the same character and saved progress in Discord and the web Activity.
- Story chapters, battles, equipment, familiars, and rewards save server-side and survive reconnects.
- Attack/spell/familiar controls work in real encounters and display appropriate health/mana/turn feedback.
- Two or more players can join a party, see synchronized state, and complete supported co-op quests.
- PvP is opt-in and server-validated; one player's client cannot grant itself rewards or modify another player's state.
- Mobile and desktop layouts remain usable, including iOS touch controls and browser audio restrictions.

## Implementation guardrails

- Free/low-cost first: use the current hosting and existing database/backend where viable before introducing paid services.
- No bot secrets in client code.
- No duplicate player progression stores.
- Do not claim an Activity, full story, or multiplayer is live until the corresponding end-to-end path is implemented and tested.
