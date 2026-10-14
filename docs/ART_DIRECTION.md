# Visual Art Direction

## Target
High-contrast, detailed 2D pixel art for a dark-fantasy RPG: deep violet and indigo, magenta arcane light, near-black shadows, fine gold trim, luminous runes, ornate panels, and distinct readable silhouettes.

## Quality bar
- No circle/rectangle character stand-ins in the playable build.
- No mixed art styles or inconsistent character proportions.
- No 3D renders, FBX files, or 3D models in the runtime asset pipeline.
- UI, portraits, characters, tiles, and effects must share one coherent palette and pixel density.
- Keep background and UI details from obscuring the player or combat read.
- Build art from approved designs; don't substitute generic reference images for the approved WOA designs.

## Character creation
- Male and female presentation options.
- Name entry.
- Distinct class/path silhouettes, signature equipment, outfit variants, and spell visual identity.
- Compatible hair, face, accessory, and robe options without losing class identity.

## Initial art set
1. Player wizard designs for both presentation options.
2. Player idle, walk/run, melee, cast, jump/land, hurt, defeat, interact, chest/item animations, with directional coverage as supported.
3. Mathias character and portrait expressions; idle, walk/run, melee, cast, hurt, defeat, interact.
4. Opening-town tileset, ground variation, buildings, trees, props, lanterns, magical details, and collision map.
5. Spell/effect animations: Magic Bolt, Arcane Blast, Shield, Teleport, Meteor, Healing, Summon, Explosion.
6. Menu frames, class icons, portraits, HUD, inventory icons, and dialogue panels.

## Class concepts to reconcile before production
Ember Mage (fire), Frostweaver (ice), Verdant Warden (nature), Storm Herald (storm), Voidcaller (shadow), Sigilbinder (arcane). These are art-direction concepts only; check the live bot/repository definitions before locking class names and abilities.

## Asset delivery rules
- Keep originals unchanged in `assets/art-source/`.
- Runtime sprites must be clean transparent PNGs with no presentation-board labels, frames, or background.
- Every sheet must have a documented frame width/height, frame count, animation name, and frame rate.
- Keep a consistent origin/pivot and pixel density.
- Disable texture filtering for pixel art and verify crisp rendering on phone and desktop.
