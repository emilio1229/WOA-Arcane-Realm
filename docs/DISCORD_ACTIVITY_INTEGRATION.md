# Discord Activity integration — staged plan

## Current safe prototype

- `activity-preview/index.html` is a responsive, self-contained UI preview for the proposed Discord Activity.
- It demonstrates the hub and navigation for Chronicle, PvE, PvP, Familiars, Grand Sigil Exchange, and Codex.
- It intentionally uses sample display values and does not authenticate, call the bot API, spend Sigils, or mutate game data.
- The existing `playtest-2d/index.html` remains the website/game entry point.

## Integration stages

1. **Visual review:** confirm the hub layout and mobile behavior before wiring any real systems.
2. **Discord Activity bootstrapping:** add the Embedded App SDK and configure the Discord application ID, Activity URL mapping, and OAuth flow. Never put a bot token or API secret in browser code.
3. **Read-only player context:** establish the signed-in Discord identity, then add authenticated server-side endpoints for the minimum player data the Activity needs.
4. **Existing game data:** map the Activity to the existing ArcaneCharacter, ArcaneQuestProgress, familiar, inventory, and Sigil records. Do not create duplicate progression stores.
5. **Server-authoritative actions:** route battles, rewards, purchases, PvP actions, and equipment changes through trusted backend services; validate ownership, costs, and progression server-side.
6. **Rollout:** test in a Discord development application and on mobile, then expose the Activity from the existing `/realm` Arcane Realm entrance without removing current fallback interactions.

## Safety rules

- Keep changes on the `activity-prototype` branch until reviewed.
- Do not change the existing `/realm` command or production database schema as part of the visual prototype.
- Do not treat Discord client context as proof of authorization; verify identity and permissions server-side.
- Keep all secrets in server-side environment variables.
