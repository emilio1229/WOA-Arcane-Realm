# Piskel workflow for WOA Arcane Realm

Piskel is a pixel-art editor; the companion `piskel-website` repository is the older website/backend project, not the editor itself.

- Editor source: https://github.com/piskelapp/piskel
- Website repository shared by the project owner: https://github.com/piskelapp/piskel-website
- Piskel web app: https://www.piskelapp.com/
- Piskel documentation: https://github.com/piskelapp/docs

The editor project is Apache-2.0 licensed. Review the upstream license and bundled notices before redistributing a self-hosted build. We do not vendor or fork the editor into the game in this workflow.

## How we will use it

1. Open Piskel on a desktop browser. The upstream README says mobile/tablet use is not supported.
2. Create each character as a small, consistent pixel-art sprite. Keep a fixed canvas size, transparent background, palette, facing direction, and foot position.
3. Make genuinely distinct frames for each loop: idle, walk, cast, and attack. Do not duplicate one image and label it an animation.
4. Export a PNG sprite sheet (and keep the editable Piskel project file as the source of truth).
5. Put approved exports in `web/assets/sprites/`, with descriptive names such as `player-storm-herald.png` and `mathias-walk.png`. Include a short README noting frame size, columns, frame order, and frame rate.
6. Integrate the sheet into Phaser with a named animation and test it at desktop and phone viewport sizes before replacing the current temporary concept crops.

## First asset milestone

- Player wizard: idle + 4-frame walk + cast + attack.
- Mathias: idle + walk + support action.
- One enemy: idle + 4-frame movement + attack.
- One familiar: idle + attack.

The current concept-sheet crops remain temporary reference art until proper frame sheets are approved. This keeps existing story, PvP/PvE, profile, and familiar data intact while the visuals improve.

## Free-first note

Use the editor and local exports; no paid generation API is required. Keep the game's runtime independent of Piskel, so the editor can be used as an art-production tool without introducing a large dependency into the deployed game.
