import bpy, sys
bpy.ops.import_scene.fbx(filepath=sys.argv[sys.argv.index('--')+1])
for mat in bpy.data.materials:
    if not mat.use_nodes:
        continue
    for node in mat.node_tree.nodes:
        if node.type == 'BSDF_PRINCIPLED':
            r = node.inputs['Roughness']
            m = node.inputs['Metallic']
            s = node.inputs.get('Specular IOR Level') or node.inputs.get('Specular')
            print(f"MAT: {mat.name}")
            print(f"  Roughness: {r.default_value:.3f}  linked={r.is_linked}")
            print(f"  Metallic:  {m.default_value:.3f}  linked={m.is_linked}")
            if s:
                print(f"  Specular:  {s.default_value:.3f}  linked={s.is_linked}")
