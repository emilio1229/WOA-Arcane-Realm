# CC0 Asset Integration Plan

This project may use third-party assets only when the exact source page confirms that attribution is not required.

## First approved source: interface art

- Pack: Kenney UI Pack
- Official page: https://kenney.nl/assets/ui-pack
- License shown on source page: Creative Commons CC0
- Attribution required: No
- Intended use: UI panels, buttons, sliders, and interface framing only
- Status: License checked; files have not yet been imported into this repository

## Integration rules

1. Import only the interface elements needed by the game. Do not copy unrelated assets from a pack.
2. Keep the original downloaded archive outside the deployed web root; commit only the selected optimized PNGs and this register.
3. Preserve pixel edges with nearest-neighbor scaling.
4. Recolor and frame the interface to match WoA's dark purple, pink, and arcane-gold theme.
5. Do not replace game logic, player progression, story data, familiars, PvP/PvE systems, or the existing /realm entrance as part of an art pass.
6. Before any future pack is imported, verify its individual license and inspect its contents. Reject anything that requires attribution or contains unrelated content we do not intend to use.

## Next implementation step

Import a small, selected set of UI PNGs from the approved pack, then wire them into the existing game UI and test on mobile. World art will be evaluated separately so each source can be reviewed without pulling in an entire unrelated bundle.
