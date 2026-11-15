# Arcane Realm prototype brief

## Confirmed project context

- Dedicated repository: emilio1229/WOA-Arcane-Realm.
- Purpose: standalone Arcane Realm game and test-build development, with the user and Claude collaborating.
- Repository boundary: do not modify the WoA website or event-bot repositories.
- Product shape: browser-first, mobile-friendly fantasy RPG.
- Visual preference: higher-angle isometric / dimensional presentation; not 2D pixel art.
- Explicit exclusion: Godot.
- Preferred technical direction discussed: Phaser/TypeScript or another lightweight browser approach. This is not a final engine decision.
- Gameplay preference: active combat and interaction; avoid making the game mostly reading and button-only interactions.
- Game systems of interest: open-world exploration, portal travel, NPCs, quests, familiars, spells, character progression, and Sigils.
- Economy boundary: Sigils are the game/Discord RPG currency concept. ARK dinos and blueprints are not desired as rewards at this stage.
- Internal development tools and Claude skills are not player-facing game features.

## Rendering decision that must be handled honestly

Phaser is a 2D HTML5 framework, not a native 3D engine. It may support an isometric or 2.5D presentation, but the project must prove that the result meets the desired dimensional look before locking it in. If true 3D is essential, evaluate a lightweight browser 3D renderer before selecting the engine. Do not silently downgrade the visual target to pixel art or flat 2D.

## Previous test-build concept (historical design context, not present code)

A prior standalone test-build concept included:

- A Grand Portal main menu and loading sequence.
- Character creation with five traditions: Arcane, Ember, Frost, Verdant, and Shadow.
- An isometric sanctuary with six buildings.
- NPC concepts: Archmage Elowen, Archivist Quill, Keeper Moth, Innkeeper Pip, Merchant Zia, Smith Brannoc, and Warden Sable.
- A Quest Board and a “Sleeping Portal” quest chain:
  1. Read the Quest Board.
  2. Speak to Elowen.
  3. Awaken the Grand Portal.
  4. Defeat three Ember Wisps.
  5. Return to the portal and claim the reward.
  6. Find Keeper Moth to unlock the familiar Glimmer.
- Arcane Bolt combat targeting the nearest enemy in range.
- XP, leveling, Sigil rewards, and an inventory/satchel.
- Keyboard controls: WASD/arrows to move, E/Enter to interact, Q/Space to cast, I for inventory, Escape for menus.
- Mobile joystick plus interaction and cast buttons.
- Local-only playtest save data with field validation/clamping and a clear disclaimer that it was not connected to live player data.

These are recoverable design notes from an earlier test concept. The current repository did not contain that game code when inspected. Rebuild only after checking the updated project direction and deciding what belongs in the first vertical slice.

## Gameplay and UX principles

- Make the world feel explorable and alive; use the Grand Portal as a strong navigation and story anchor.
- Prioritize responsive movement, readable combat, meaningful enemy encounters, and tangible rewards.
- Keep dialogue purposeful and skippable; deliver lore through environment, NPC moments, quests, and optional discoveries.
- Design touch controls from the beginning, not as an afterthought.
- Keep player-facing interfaces clean, legible, and usable on desktop and mobile.
- Character traditions are visual identity/progression themes; robe recoloring was the preferred tradition expression, rather than radically different body models.
- Build a small complete loop before expanding the world: explore → encounter → fight/interact → earn progress → return/claim/unlock.

## Still unresolved

- Final rendering technology and whether 2.5D is sufficient or true 3D is mandatory.
- Exact first playable map and the first vertical-slice acceptance checklist.
- Final character classes/stats, combat rules, enemy roster, progression curve, and save model.
- Whether the initial prototype is local-only or includes a backend.
- Art style reference sheet, animation requirements, sound direction, and asset licensing.
- Hosting, distribution, and eventual Discord Activity integration details.

Do not treat unresolved items as agreed. Record decisions here when the user makes them.
