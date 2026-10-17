# WoA Arcane Realm — Phaser Occlusion Prototype

An isolated visual experiment for a smooth follow camera and a magical fade effect when the player approaches objects that would obscure them.

## Run it
Open `index.html` in a browser with an internet connection (the Phaser 3.90 library loads from jsDelivr). Use **WASD / arrow keys** or the on-screen directional pad. Use **Reset position** to return to the starting point.

## What this tests
- A smoothly following camera using Phaser's built-in 2D camera.
- A fantasy sanctuary scene with simple placeholder art.
- A purple fade effect on nearby objects in front of the character.
- Responsive layout and touch controls.

## Important limitations
This is a visual prototype, not final art and not a 3D over-the-shoulder camera. The occlusion test uses simple 2D proximity/depth rules rather than true line-of-sight raycasting. It is intended to evaluate the camera feel and visibility concept before investing in production assets.

It is deliberately isolated from `playtest-2d/`, `isometric-prototype/`, Discord bot code, and player save data. No backend or account data is touched.
