# Free 3D Game Asset Sources — CC0 / No Attribution

Research date: 2026-10-17. This is a shortlist, not a record of assets already integrated into the game. Verify the license on the individual source page before importing or shipping.

## First choices for the Arcane Realm

### Nature, trees, rocks, foliage
- **Kenney Nature Kit** — https://kenney.nl/assets/nature-kit
- License: CC0; attribution not required.
- Intended use: stylized trees, rocks, foliage, and natural props. Keep this kit's simpler flat-color style consistent rather than mixing every prop pack together.
- License reference: https://kenney.nl/support

### Medieval fantasy settlement pieces
- **Kenney Fantasy Town Kit** — https://kenney.nl/assets/fantasy-town-kit
- License: CC0; attribution not required.
- Intended use: modular town buildings and settlement dressing.

### Retro fantasy buildings and props
- **Kenney Retro Fantasy Kit** — https://kenney.nl/assets/retro-fantasy-kit
- License: CC0; attribution not required.
- Intended use: fantasy/medieval props where the slightly retro look fits the chosen art direction.

### PBR ground, stone, bark, and terrain textures
- **ambientCG** — https://ambientcg.com/
- License: CC0; attribution not required.
- Intended use: ground, rock, stone, wood, and other seamless material textures. Use appropriately downscaled maps for mobile.

### Environment models, materials, and lighting HDRIs
- **Poly Haven** — https://polyhaven.com/
- License: CC0; attribution not required.
- License terms: https://polyhaven.com/license
- Intended use: selective environment props, surface materials, and lighting maps. Prefer optimized/downscaled versions; avoid huge texture maps in the mobile build.

### More stylized low-poly nature options
- **Quaternius** — https://quaternius.com/
- Intended use: compare stylized vegetation and environment packs against Kenney before choosing one consistent visual family.
- Important: verify the license on each individual pack page before importing; do not assume every third-party mirror or re-upload has the same terms.

### Small stylized house set
- **Tiny Treats — Homely House** — https://tinytreats.itch.io/homely-house
- License: CC0, no attribution required, according to the publisher's page.
- Intended use: optional settlement accents if its style matches the main building kit.

## Selection and integration rules

1. Prefer original publisher pages and CC0 / CC0 1.0 statements. "Free" alone does not mean no attribution.
2. Do not import assets from unverified mirrors, ripped games, or packs with unclear redistribution terms.
3. Keep a local manifest with source URL, pack name, license, date checked, and the exact files used.
4. Download only the models needed for the first region; prefer GLB/glTF when available, then optimize textures and geometry for mobile.
5. Use a cohesive art direction: choose one main environment style, then test any secondary pack in the same scene before expanding it.
6. Asset sourcing is not asset integration. Do not mark a pack as "in game" until the files are committed, loaded by the runtime, and visually checked.
7. This research document does not grant rights to any third-party material beyond the licenses stated by its original publisher. Re-check each pack's live license before release.

## Proposed first import batch

- Nature: Kenney Nature Kit.
- Settlement: Kenney Fantasy Town Kit.
- Materials: a small set of ambientCG grass/soil/stone textures.
- Lighting: one low-resolution Poly Haven HDRI only if it performs well on target phones.

Test this combination in one small 3D region first. Keep the current browser game and its player/story data intact while the 3D scene is developed and validated.
