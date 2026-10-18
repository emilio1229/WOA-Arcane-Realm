# WOA Arcane Realm — Godot 3D World Prototype

This is an isolated Godot 4 prototype for the new procedural 3D environment. It does **not** replace the live Phaser/browser game and does not touch player saves, story progression, Discord bot logic, or the existing isometric browser prototype.

## Open it

1. Install Godot 4.x (free).
2. Import this folder as a project by opening `project.godot`.
3. Run the project.

## First milestone

- Deterministic seed-based terrain dressing.
- A connected meadow, forest edge, stream, rune landmark, crystals, rocks, and simple ruins.
- Generated reusable low-poly mesh props as a temporary art blockout.
- Isometric-style camera and keyboard movement.
- On-screen seed controls to regenerate the environment.

## Important art status

The meshes in this first pass are procedural blockout assets, not the finished handcrafted art library. The next pass should replace or augment them with coherent, optimized tree, rock, terrain, ruin, crystal, and building assets. Keep the world-generation interface and seed behavior stable while replacing visuals.

## Mobile plan

This is a desktop-testable foundation, not yet a mobile-ready release. After verifying the project opens and generates correctly in Godot, add touch movement controls, profile-safe world persistence, region streaming, and Android/web export tests. Web export is a separate performance decision; it must be tested on actual target phones before integrating it into the live game.

## World generation contract

Same seed + same settings = same placement. Different seeds change placement without breaking important traversal routes. Player/story saves remain separate from world settings.
