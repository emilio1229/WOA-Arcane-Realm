# WOA: Arcane Realm

A Godot 4 third-person fantasy adventure prototype for The Wizards of Ark, being prepared for browser play on the WOA website and as a Discord Activity.

## Play and develop locally

1. Clone this repository with GitHub Desktop.
2. In Godot 4.7.2, choose **Import** and select `project.godot`.
3. Press **F6** or **F5** to run the game.

## Current playable foundation

- Start screen and wizard name entry
- Procedurally built purple-lit sanctuary, pillars, and glowing sigil
- Third-person WASD movement, mouse camera, and jumping
- Mathias NPC with a multi-step opening conversation
- Basic objective prompt and story progression

## Controls

- **WASD** — move
- **Mouse** — look around
- **Space** — jump
- **E** — speak to Mathias / continue dialogue
- **Esc** — release mouse capture

## Browser build

This repository includes a Godot **Web** export preset and a Dockerfile intended for Railway:

- `export_presets.cfg` — Web export preset targeting `build/index.html`
- `Dockerfile` — exports the game, then serves the exported files with Nginx
- `deploy/nginx.conf` — serves WebAssembly with the correct MIME type
- `.github/workflows/web-build.yml` — builds the Docker image on pushes and pull requests

The web export uses Godot's Compatibility renderer and disables web thread support for simpler hosting. Godot Web exports require WebAssembly and WebGL 2.0 support in the player's browser.

## Railway deployment

1. In Railway, create a new project/service from this GitHub repository.
2. Set the service builder to **Dockerfile** and use the repository-root `Dockerfile`.
3. Deploy and wait for the build to complete.
4. Generate a Railway public domain and test the game there before changing DNS.
5. After the Railway URL works, add `play.thewizardofark.com` as a custom domain in Railway and follow the DNS record instructions shown by Railway in Cloudflare.

Do not change the main website's DNS records when adding the game subdomain. Only add the exact record Railway instructs you to create.

## Discord

The browser version is the foundation for a Discord Activity. Discord app configuration and Embedded App SDK integration are separate steps to complete after the hosted browser build is working.

## Important status note

The deployment files are committed, but the image has not yet been verified by a successful remote build and the game has not yet been tested in a browser. Confirm the Railway build and test the generated game before sharing it with players.
