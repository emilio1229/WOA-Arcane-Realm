# Third-Party Notices

This file records third-party components identified during the WOA: Arcane Realm review. It is not a blanket license for this game, its original story, or its original assets.

## Godot Engine

WOA: Arcane Realm is built with Godot Engine 4.7.2. Godot is distributed under the MIT License. The official license and compliance guidance are available at:

- https://godotengine.org/license/
- https://docs.godotengine.org/en/stable/about/complying_with_licenses.html

## Bundled add-ons found in the repository

The license files shipped alongside each add-on are authoritative and should stay with the add-on source.

| Component | License / status | Repository location |
|---|---|---|
| Any AudioManager | CC0, as stated in its plugin configuration | `addons/any_audio_manager/` |
| SimpleGrassTextured | MIT | `addons/simplegrasstextured/LICENSE` |
| Health, HitBoxes, HurtBoxes, and HitScans | MIT | `addons/health_hitbox_hurtbox/LICENSE` |
| Terrain3D | MIT | `addons/terrain_3d/LICENSE.txt` |
| Sky3D | MIT; star-map textures have separate notices | `addons/sky_3d/LICENSE.txt` and its third-party texture license files |
| Ragdoll Generator | MIT | `addons/ragdoll_generator/LICENSE` |
| Modular Builder (English) | CC0 applies to its original code/icons/docs only; demo textures are not automatically covered | `addons/modular_builder_en/LICENSE` |
| Tripo3D Godot Bridge | License not verified during this review | `addons/Tripo3d_Godot_Bridge/` |
| Animation Combiner | License not verified during this review | `addons/animation_combiner/` |

## Release note

The Tripo3D Bridge and Animation Combiner folders did not have an obvious license file at the expected add-on root. Their redistribution terms, and the provenance of the project's imported model/OBJ/texture packs, still need verification before treating the whole repository as cleared for public or commercial distribution. Do not interpret the absence of a top-level project license as permission to ignore the licenses attached to bundled components.
