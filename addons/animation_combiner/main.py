#!/usr/bin/env python3
"""
Combine multiple FBX animations onto a single character and export as GLB/GLTF.

Requirements:
    - Blender's Python module "bpy" must be available
      (either run inside Blender or install "bpy" from PyPI).
"""

import argparse
import json
import os
import re
import sys
import traceback

try:
    import bpy  # type: ignore
except ImportError:
    print(
        "Error: this script requires Blender's 'bpy' module.\n"
        "Run it from Blender, or install 'bpy' into your Python environment.",
        file=sys.stderr,
    )
    sys.exit(1)


def parse_args(argv=None) -> argparse.Namespace:
    if argv is None:
        argv = sys.argv[1:]
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    parser = argparse.ArgumentParser(
        description="Combine FBX animations into a single GLB file."
    )
    parser.add_argument("--model", required=True,
        help="Base FBX file with the character mesh and skeleton.")
    parser.add_argument("--animations", nargs="+", required=True,
        help="One or more FBX files that contain animations for the same rig.")
    parser.add_argument("--output", required=True,
        help="Path to the resulting GLB/GLTF file (e.g. final.glb or final.gltf).")
    parser.add_argument("--json-output", action="store_true",
        help="Output results as JSON for programmatic parsing.")
    return parser.parse_args(argv)


def clear_scene() -> None:
    """Remove all existing objects and unused data from the scene."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for collection in (
        bpy.data.meshes,
        bpy.data.armatures,
        bpy.data.materials,
        bpy.data.actions,
        bpy.data.images,
    ):
        for block in list(collection):
            if not block.users:
                collection.remove(block)


def import_fbx(filepath: str):
    """Import an FBX file and return the list of newly created objects."""
    if not os.path.isfile(filepath):
        raise FileNotFoundError(filepath)
    before_objects = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=filepath)
    return [obj for obj in bpy.data.objects if obj not in before_objects]


def choose_main_armature(objects) -> bpy.types.Object:
    """Return the armature with the most bones — works well for Mixamo-style rigs."""
    armatures = [obj for obj in objects if obj.type == "ARMATURE"]
    if not armatures:
        raise RuntimeError("No armature found in the imported base model.")
    return max(armatures, key=lambda a: len(a.data.bones))


def fix_materials(meshes) -> None:
    """
    Correct PBR values that Blender's FBX importer sets incorrectly.

    The FBX-to-PBR conversion maps FBX specular intensity onto Blender's Metallic
    socket, producing values around 0.5 for non-metallic geometry (skin, hair, fabric).
    Resets unlinked Metallic to 0.0 and floors unlinked Roughness at 0.3 so the
    exported GLTF matches the original FBX appearance in Godot.
    """
    for mesh_obj in meshes:
        for mat_slot in mesh_obj.material_slots:
            mat = mat_slot.material
            if not mat or not mat.use_nodes:
                continue
            for node in mat.node_tree.nodes:
                if node.type != 'BSDF_PRINCIPLED':
                    continue
                metallic = node.inputs['Metallic']
                roughness = node.inputs['Roughness']
                if not metallic.is_linked and metallic.default_value > 0.0:
                    print(f"[INFO] {mat.name}: resetting Metallic {metallic.default_value:.3f} -> 0.0")
                    metallic.default_value = 0.0
                if not roughness.is_linked and roughness.default_value < 0.3:
                    print(f"[INFO] {mat.name}: clamping Roughness {roughness.default_value:.3f} -> 0.3")
                    roughness.default_value = 0.3


def import_base_model(model_path: str):
    """
    Import the base character FBX and return (armature, meshes).
    Actions bundled with the base model are discarded — animations come from anim FBXs.
    """
    print(f"[INFO] Importing base model: {model_path}")
    actions_before = set(bpy.data.actions)
    new_objects = import_fbx(model_path)

    for action in list(bpy.data.actions):
        if action not in actions_before:
            bpy.data.actions.remove(action)

    armature = choose_main_armature(new_objects)
    meshes = [obj for obj in new_objects if obj.type == "MESH" and obj.parent == armature]
    if not meshes:
        meshes = [obj for obj in new_objects if obj.type == "MESH"]
    if not meshes:
        print("[WARN] No mesh objects found in the base model; only the armature will be exported.")

    print(f"[INFO] Using armature: {armature.name}")
    for m in meshes:
        print(f"[INFO] Using mesh: {m.name}")

    fix_materials(meshes)
    return armature, meshes


def build_bone_remap(base_armature: bpy.types.Object, anim_armature: bpy.types.Object) -> dict:
    """
    Build a dict mapping anim bone names -> base armature bone names.
    Strips any 'prefix:' namespace from both sides and matches on the bare name.
    """
    def strip_prefix(name: str) -> str:
        return name.split(":")[-1] if ":" in name else name

    base_by_bare = {strip_prefix(b.name): b.name for b in base_armature.data.bones}
    remap = {}
    for bone in anim_armature.data.bones:
        bare = strip_prefix(bone.name)
        if bare in base_by_bare:
            target = base_by_bare[bare]
            if bone.name != target:
                remap[bone.name] = target
    return remap


def remap_action_bone_paths(action: bpy.types.Action, remap: dict) -> None:
    """
    Rewrite fcurve data_paths in-place so 'pose.bones["OldName"]...' becomes
    'pose.bones["NewName"]...'. Supports both legacy and Blender 4.4+ layered actions.
    """
    if not remap:
        return

    pattern = re.compile(r'pose\.bones\["([^"]+)"\]')

    def replacer(m):
        old = m.group(1)
        new = remap.get(old, old)
        return f'pose.bones["{new}"]'

    def remap_fcurves(fcurves):
        for fc in fcurves:
            new_path = pattern.sub(replacer, fc.data_path)
            if new_path != fc.data_path:
                fc.data_path = new_path

    # Blender 4.4+ layered action system
    if hasattr(action, 'layers'):
        for layer in action.layers:
            for strip in layer.strips:
                if hasattr(strip, 'channelbags'):
                    for channelbag in strip.channelbags:
                        remap_fcurves(channelbag.fcurves)
    # Legacy direct fcurves (pre-4.4)
    elif hasattr(action, 'fcurves'):
        remap_fcurves(action.fcurves)


def add_animations_from_fbx(base_armature: bpy.types.Object, anim_path: str):
    """
    Import a FBX that contains an animation and copy its actions to the base armature.
    Assumes the animation FBX has the same rig structure (e.g. Mixamo).
    Caller is responsible for ensuring anim_path exists.
    """
    print(f"[INFO] Importing animation FBX: {anim_path}")

    actions_before = set(bpy.data.actions)
    objects_before = set(bpy.data.objects)

    bpy.ops.import_scene.fbx(filepath=anim_path)

    new_actions = [a for a in bpy.data.actions if a not in actions_before]
    new_objects = [o for o in bpy.data.objects if o not in objects_before]

    base_name = os.path.splitext(os.path.basename(anim_path))[0]
    created_actions = []

    if not new_actions:
        print(f"[WARN] No new actions detected from '{anim_path}'. Is this FBX actually containing animation?")

    remap = {}
    anim_armatures = [o for o in new_objects if o.type == "ARMATURE"]
    if anim_armatures:
        remap = build_bone_remap(base_armature, anim_armatures[0])
        if remap:
            print(f"[INFO] Remapping {len(remap)} bone name(s) to match base armature")

    if base_armature.animation_data is None:
        base_armature.animation_data_create()

    for idx, src_action in enumerate(new_actions):
        new_action = src_action.copy()
        new_action.name = base_name if len(new_actions) == 1 else f"{base_name}_{idx}"
        remap_action_bone_paths(new_action, remap)
        new_action.use_fake_user = True
        # Note: id_root was removed in Blender 4.4+; use_fake_user is sufficient
        base_armature.animation_data.action = new_action
        print(f"[INFO] Added action: {new_action.name}")
        created_actions.append(new_action)

    for obj in new_objects:
        if obj == base_armature:
            continue
        bpy.data.objects.remove(obj, do_unlink=True)

    for src_action in new_actions:
        src_action.use_fake_user = False
        bpy.data.actions.remove(src_action)

    # Purge orphaned data left by the animation FBX
    for block in list(bpy.data.meshes):
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in list(bpy.data.materials):
        if block.users == 0:
            bpy.data.materials.remove(block)
    for block in list(bpy.data.images):
        if block.users == 0:
            bpy.data.images.remove(block)
    for block in list(bpy.data.armatures):
        if block.users == 0:
            bpy.data.armatures.remove(block)

    return created_actions


def detect_texture_conflicts() -> list:
    """
    Detect materials whose base name (ignoring Blender's .001/.002 suffix) is shared,
    which can cause conflicts during GLTF export.
    """
    mat_names = {
        mat_slot.material.name
        for obj in bpy.data.objects
        if obj.type == "MESH"
        for mat_slot in obj.material_slots
        if mat_slot.material
    }

    base_name_groups: dict = {}
    for mat_name in mat_names:
        parts = mat_name.rsplit(".", 1)
        base = parts[0] if len(parts) == 2 and parts[1].isdigit() else mat_name
        base_name_groups.setdefault(base, []).append(mat_name)

    return [
        f"Material '{base}' has multiple variants: {', '.join(variants)}"
        for base, variants in base_name_groups.items()
        if len(variants) > 1
    ]


def export_gltf(output_path: str) -> None:
    """Export the current scene as a GLTF or GLB file."""
    output_path = os.path.abspath(output_path)
    out_dir = os.path.dirname(output_path)
    if out_dir and not os.path.exists(out_dir):
        print(f"[INFO] Creating output directory: {out_dir}")
        os.makedirs(out_dir, exist_ok=True)

    export_format = "GLB" if output_path.lower().endswith('.glb') else "GLTF_SEPARATE"
    print(f"[INFO] Exporting {export_format} to: {output_path}")

    if not bpy.data.objects:
        raise RuntimeError("No objects in scene to export")

    bpy.ops.object.select_all(action='SELECT')
    result = bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format=export_format,
        use_selection=False,
        export_animations=True,
        export_skins=True,
        export_morph=False,
        export_image_format='AUTO',
    )

    if result != {'FINISHED'}:
        raise RuntimeError(f"GLTF export failed with result: {result}")
    if not os.path.exists(output_path):
        raise RuntimeError(f"Export reported success but file was not created at: {output_path}")

    print(f"[INFO] Export complete. File size: {os.path.getsize(output_path)} bytes")


def main():
    args = parse_args()

    model_path = os.path.abspath(args.model)
    anim_paths = [os.path.abspath(p) for p in args.animations]
    output_path = os.path.abspath(args.output)
    json_output = args.json_output

    result = {
        "success": False,
        "texture_conflicts": [],
        "error": None,
        "animations_added": [],
        "output_file": output_path,
    }

    try:
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Base model not found: {model_path}")
        for anim_path in anim_paths:
            if not os.path.exists(anim_path):
                raise FileNotFoundError(f"Animation file not found: {anim_path}")

        clear_scene()
        base_armature, _meshes = import_base_model(model_path)
        if not base_armature:
            raise RuntimeError("Failed to import base armature")

        for anim_path in anim_paths:
            actions = add_animations_from_fbx(base_armature, anim_path)
            result["animations_added"].extend([a.name for a in actions])

        print(f"[INFO] Total animations added: {len(result['animations_added'])}")

        conflicts = detect_texture_conflicts()
        if conflicts:
            result["texture_conflicts"] = conflicts
            for conflict in conflicts:
                print(f"[WARN] Texture conflict: {conflict}")

        export_gltf(output_path)

        if os.path.exists(output_path):
            result["success"] = True
            print(f"[SUCCESS] Export completed: {output_path}")
        else:
            raise RuntimeError(f"Export function completed but file not found: {output_path}")

    except Exception as e:
        result["error"] = str(e)
        result["success"] = False
        print(f"[ERROR] {e}", file=sys.stderr)
        traceback.print_exc()
        if not json_output:
            raise

    if json_output:
        print("===JSON_START===")
        print(json.dumps(result, indent=2))
        print("===JSON_END===")

    if not result["success"]:
        sys.exit(1)


if __name__ == "__main__":
    main()