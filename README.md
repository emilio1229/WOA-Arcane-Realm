# WOA: Arcane Realm

A browser-playable third-person fantasy adventure set in The Wizards of Ark universe. The current build is the opening playable chapter, **The Sigil Sanctuary**. The game is built in Godot 4 and served as a web export through Railway.

## Play

Open the deployed game: https://woa-arcane-realm-production.up.railway.app

## Chapter One: The Sigil Sanctuary

- Create your wizard by entering a name on the title screen, then use **Continue Journey** to resume saved sigil and trial progress.
- Meet Mathias, keeper of the first sigil, and learn why the sanctuary wards are failing.
- Explore the sanctuary and recover the three ancient crystals: **Dawn**, **Dusk**, and **Heart**.
- Watch the ward change when all three sigils are recovered.
- Return to the monumental gate and enter the First Trial arena.
- Fight the Sanctuary Guardian: use **F** for close staff strikes and **Q** for ranged arcane bolts. Dodge its approach and survive to win the chapter.

This is an early playable vertical slice, not the finished full game. The world is assembled procedurally and uses categorized GLB assets where they are wired into gameplay; missing or invalid models fall back to procedural visuals. Rigged animation, sound, more levels, richer progression, and Discord Activity integration remain planned development work.

## Controls

- **WASD / Arrow keys** — move
- **Mouse** — look around (click the game to capture the cursor)
- **Space** — jump
- **Shift** — run
- **E** — talk, collect a sigil, or interact with the gate
- **F** — staff strike during the guardian trial (close range)
- **Q** — cast an arcane bolt during the guardian trial (ranged)
- **Esc** — release the cursor

The game automatically saves your wizard name and major quest progress in the browser. Browser storage settings or clearing site data can affect local saves.

## Project structure and local development

1. Open Godot 4.7.2.
2. Import `project.godot`.
3. Press **F6** or **F5** to run the game.

`main.tscn` contains only the game root and its script. `main.gd` builds the world and loads models at their intended locations. Source models are grouped under `assets/models/characters`, `creatures`, `environment`, `architecture`, and `props`. The generated `.godot/` cache is intentionally excluded from Git; Godot recreates it on import.

## Browser build and deployment

- `export_presets.cfg` — Godot Web export preset targeting `build/index.html`
- `Dockerfile` — exports the game and serves the result with Nginx
- `deploy/nginx.conf` — web server configuration, including WebAssembly MIME support
- `.github/workflows/web-build.yml` — validates the container build on pushes and pull requests

The web export uses Godot's Compatibility renderer and disables web thread support for simpler hosting. Players need a modern browser with WebAssembly and WebGL 2.0 support.

Railway is currently hosting the public test build. Keep the current public URL working while improving the game; only configure the custom domain after the current build is verified.

## Roadmap

1. **Opening chapter** — movement, Mathias dialogue, three collectible sigils, gate activation, and the first guardian boss fight.
2. **Core adventure systems** — real character model and animations, camera polish, sound, spell casting, inventory, and save data.
3. **World expansion** — additional realms, story quests, puzzles, enemies, and boss encounters.
4. **Player experience** — settings, accessibility, responsive UI, controller support, and performance optimization.
5. **Community launch** — Discord Activity integration and connection to WOA community features.
