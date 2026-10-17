# WoA Arcane Realm — Isometric Prototype

This is an isolated visual/movement prototype. It does not replace `playtest-2d/index.html`, alter the Discord bot, or modify player saves/data.

## Try it
Open `index.html` in a browser. Move with WASD/arrow keys or the touch pad. Walk near the glowing rune and press E/Enter (or tap the screen's interaction area by using a keyboard on desktop; touch interaction can be added as the next pass).

## Current milestone
- Responsive canvas and safe-area-aware HUD for portrait and landscape layouts.
- Isometric tile field, small town buildings, trees, glowing rune, character movement and interaction feedback.
- No libraries, external assets, API keys, or paid services.

## Next
1. Test on a real phone in portrait and landscape.
2. Replace the temporary drawn character and environmental shapes with a consistent, properly licensed pixel-art tileset and directional animation sheets.
3. Add tile collision/navigation and camera scaling/panning.
4. Integrate with the existing character/progression/save model only after identifying the current data contract and verifying compatibility.
5. Connect this as the new game view behind the existing Discord `/realm` → Arcane Realm entrance, without creating a second player profile or resetting progression.

This prototype is not yet connected to Discord Activity, PvP/PvE systems, familiars, or production saves.