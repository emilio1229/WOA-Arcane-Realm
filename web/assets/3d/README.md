# 3D Asset Intake

The asset catalog is in `asset-manifest.json`. The production Dockerfile already copies `web/assets/` into the site, so assets placed here will be included in the deployed image.

## Status

This directory currently contains the catalog, **not the downloaded model packs**. Do not treat a catalog entry as an integrated game asset. The connected GitHub action can commit text/code but does not provide a direct binary-download-and-upload workflow for publisher ZIP files in this session.

## Import targets

Use the original publisher pages in `asset-manifest.json` and download only from those pages. Extract selected files into these folders:

- `kenney/nature-kit/` — first priority: trees, rocks, foliage.
- `kenney/fantasy-town-kit/` — second priority: modular buildings and settlement pieces.
- `kenney/retro-fantasy-kit/` — optional; only keep pieces that match the final art direction.
- `ambientcg/` — small 1K JPG material maps only, for mobile performance.
- `polyhaven/` — optional low-resolution HDRI, only if the performance test supports it.

Include each pack's original `License.txt` or license record next to its files. Never mix a pack into the production world until the actual model files are present, loaded by the runtime, and visually checked.

## Art direction

Use Kenney Nature Kit and Fantasy Town Kit as the primary cohesive low-poly style. Retro Fantasy, Quaternius, and Tiny Treats are optional review candidates, not automatic additions. More assets are not automatically better; avoid a mismatched world and keep the mobile asset budget small.
