# WOA: Arcane Realm — Player Character Art Direction

## Approved visual direction

Use the generated WOA Arcane Realm character-creation concept as the visual target: high-contrast 2D pixel art, dark fantasy, deep violet and magenta magic, near-black backgrounds, fine gold trim, glowing runes, ornate panels, and readable silhouettes. The concept sheet is a design reference, not a production sprite atlas; gameplay sprites must be exported as clean, transparent, consistently sized frames.

## Character creation flow

1. Select male or female presentation.
2. Enter a character name.
3. Choose a wizard class; class determines the core outfit silhouette, equipment, signature magic, combat style, and starting abilities.
4. Customize compatible appearance options (hair, face, accessories, robe/armor variants) without losing the chosen class identity.
5. Confirm the character and enter the Realm.

## Wizard paths

Use the existing Arcane Realm bot/repository definitions as the source of truth for class names, stats, spells, unlocks, and progression. The current art-direction examples are Ember Mage (fire), Frostweaver (ice), Verdant Warden (nature), Storm Herald (storm), Voidcaller (shadow), and Sigilbinder (arcane). Do not silently replace or duplicate the live bot's definitions; reconcile names and abilities against the actual bot data before implementing them.

Each class needs a distinct sprite silhouette, palette, staff/weapon, cast effects, idle pose, and class-specific outfit variants. Gender options should share the same class identity and ability set while allowing appropriate sprite variations.

## Required player animations

- Idle
- Walk and run
- Melee attack
- Cast spell
- Jump and land
- Hurt
- Death
- Interact / talk
- Open chest and use item
- Directional facing as supported by the game (prefer 8-way if the game world/controller supports it)

Build Mathias as a separate supporting character with idle, walk, run, melee attack, cast, hurt, death, interact, portrait expressions, and his own purple battle-mage equipment.

## Spell and combat effects

Create individual transparent effect sprites/animations for Magic Bolt, Arcane Blast, Shield, Teleport, Meteor, Healing, Summon, and Explosion. Keep the effects visually consistent with the violet arcane theme, but allow class-specific colors and shapes for fire, ice, nature, storm, shadow, and arcane spells.

## Godot asset requirements

- Separate transparent PNG sprite frames or sprite sheets; do not use the whole presentation board as a runtime sprite sheet.
- Consistent frame dimensions, pivot/origin, scale, and pixel density within each animation.
- Document each sheet's frame size, frame count, animation name, and playback speed.
- Avoid baked-in labels, borders, portraits, backgrounds, or UI in gameplay sprite textures.
- Import with filtering disabled and pixel-art-friendly settings; test movement and animation in-game before expanding the sheet.
- Keep art source/reference material separate from optimized runtime sprites and effects.

## Discord and event-bot integration target

Godot remains the game client. Link the player's Discord identity to one persistent character record, and use shared backend data for class, level, XP, Sigils, inventory, equipment, unlocked spells, and quest state. Reuse the existing event bot's data model where practical rather than creating conflicting duplicate progression systems. Discord Activity support and authentication should be implemented as a separate integration step after the local web build and character-creation flow work reliably.

## Initial implementation milestone

1. Add a functional character-creation screen with name and gender selection.
2. Show selectable class cards with class-specific outfit previews and signature abilities.
3. Start with placeholder animations if necessary, but keep the sprite/animation architecture ready for replacement with production sheets.
4. Implement the chosen character in the opening village sequence with Mathias.
5. Verify the web build and mobile browser controls before connecting persistent Discord progression.
