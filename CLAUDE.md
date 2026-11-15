# Collaboration directive — WOA Arcane Realm

You are collaborating on a standalone game project in this repository. Read the README and all relevant documents under docs/ before planning or changing implementation.

## Hard repository boundaries

1. All Arcane Realm game work belongs in emilio1229/WOA-Arcane-Realm.
2. Do not edit, copy game files into, or deploy through wizardsofark-website.
3. Do not put Arcane Realm game code in woa-event-bot.
4. Do not create a different repository or move project ownership without explicit user direction.
5. Do not deploy, publish, connect production services, migrate live data, or touch real player accounts without explicit approval.
6. Do not overwrite or delete existing work as a shortcut. Inspect history and current files first.

## Product direction

- Browser-first, standalone fantasy RPG; mobile-friendly.
- Higher-angle isometric / dimensional presentation, not a 2D pixel-art aesthetic.
- Godot is explicitly excluded.
- Phaser + TypeScript is a candidate, not a locked decision. Phaser is a 2D framework; do not claim it provides native 3D. Validate any isometric/2.5D approach against the visual goal before committing to it.
- Portal-connected open world, NPCs, familiars, spells, quests, and satisfying combat.
- Favor active play and combat over long blocks of reading or button-only interactions.
- The game should own and validate its gameplay state. Discord integration, if later approved, is a bridge—not the authority for inventory, battles, quests, or currency.
- Sigils are the Discord RPG/game currency concept. Do not add ARK dinos or blueprints as game rewards at this stage.

## Internal tools are not game features

The Engineering Skills Blueprint and Arcane Artificer are development workflows for Claude/AI/staff. They must not appear as player-facing menus, NPCs, shops, crafting stations, or gameplay systems unless the user explicitly changes this rule. Do not expose secrets, diagnostics, admin controls, or asset-generation controls to ordinary players.

## Before implementation

1. Inspect repository tree, recent commits, current branch, and existing behavior.
2. Read docs/PROJECT_KNOWLEDGE_BASE.md, docs/PROTOTYPE_BRIEF.md, and relevant engineering/asset documents.
3. Separate confirmed requirements from proposals and unresolved choices.
4. If a decision materially affects engine, rendering, persistence, security, or player data and is unresolved, explain the tradeoff before making it foundational.
5. Build the smallest playable vertical slice; avoid speculative architecture and unnecessary dependencies.

## Engineering standards

- TypeScript strictness and explicit data contracts where TypeScript is selected.
- Server-authoritative validation for valuable or persistent state once online services exist.
- Never trust client-submitted currency, inventory, item rarity, stats, combat results, permissions, or timestamps.
- Idempotent operations for rewards, purchases, trades, and quest claims.
- Audit important mutations; protect against duplication, replay, race conditions, and rollback abuse.
- Backups must be restorable and restoration must be tested.
- Test normal paths, edge cases, concurrency, malicious inputs, recovery, and mobile interaction.
- Least privilege for player, staff, admin, automation, and service identities.
- No secrets in source control, client bundles, logs, screenshots, or generated assets.

## Change discipline

- Make small, reviewable, additive changes.
- Update documentation whenever a decision, architecture, command, or workflow changes.
- Keep setup, run, build, and test commands accurate.
- Run available checks and report exactly what was and was not tested.
- Never claim that a build was run, browser-tested, deployed, or secured unless that action actually happened.
- For every change, report files changed, commit/branch, validation performed, known gaps, and how the user can try it.
