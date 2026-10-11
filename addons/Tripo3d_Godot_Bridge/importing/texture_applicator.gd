# texture_applicator.gd
# PBR texture collection, matching, and material configuration
@tool
class_name TripoTextureApplicator
extends RefCounted

# ————— pub api —————

## Scan asset files and build a dictionary of texture maps keyed by part name.
## Returns { "base_color": {key: res_path}, "metallic": {…}, "roughness": {…}, "normal": {…} }
static func collect_texture_maps(asset_path: String, files: Array[String]) -> Dictionary:
	var abs_path := ProjectSettings.globalize_path(asset_path)
	var base_color_map: Dictionary = {} # part_key -> res_path
	var metallic_map: Dictionary = {}   # part_key -> res_path
	var roughness_map: Dictionary = {}  # part_key -> res_path
	var normal_map_map: Dictionary = {} # part_key -> res_path

	for f in files:
		var fname := f.get_file().to_lower()
		var base := f.get_file().get_basename().to_lower()
		# Only handle image files (.jpeg included)
		if not (fname.ends_with(".png") or fname.ends_with(".jpg")
				or fname.ends_with(".jpeg") or fname.ends_with(".tga")
				or fname.ends_with(".webp")):
			continue
		var res_path := asset_path.path_join(f.replace(abs_path + "/", ""))

		if "basecolor" in fname or "albedo" in fname or "diffuse" in fname:
			var key := _normalize_part_key(_extract_part_key(base, ["basecolor", "albedo", "diffuse"]))
			base_color_map[key] = res_path
		elif "metallic" in fname:
			var key := _normalize_part_key(_extract_part_key(base, ["metallic"]))
			metallic_map[key] = res_path
		elif "roughness" in fname:
			var key := _normalize_part_key(_extract_part_key(base, ["roughness"]))
			roughness_map[key] = res_path
		elif "normal" in fname:
			var key := _normalize_part_key(_extract_part_key(base, ["normal"]))
			normal_map_map[key] = res_path

	return {
		"base_color": base_color_map,
		"metallic": metallic_map,
		"roughness": roughness_map,
		"normal": normal_map_map,
	}


## Apply PBR textures to .tres / .material files found in asset_files.
static func apply_textures_to_materials(asset_path: String, files: Array[String],
		texture_maps: Dictionary, texture_cache: Dictionary) -> void:
	LogHelper.log("Applying textures to materials...")
	var abs_path := ProjectSettings.globalize_path(asset_path)
	var base_color_map: Dictionary = texture_maps.get("base_color", {})
	var metallic_map: Dictionary = texture_maps.get("metallic", {})
	var roughness_map: Dictionary = texture_maps.get("roughness", {})
	var normal_map_map: Dictionary = texture_maps.get("normal", {})

	# Find .tres / .material files
	var configured := 0
	for f in files:
		if not (f.ends_with(".tres") or f.ends_with(".material")):
			continue
		var res_path := asset_path.path_join(f.replace(abs_path + "/", ""))
		var mat = load(res_path)
		if not mat is StandardMaterial3D:
			continue
		var mat3d := mat as StandardMaterial3D
		var raw_name := res_path.get_file().get_basename().to_lower()
		var mat_key := _normalize_part_key(raw_name)

		var bc := _find_matching_texture(mat_key, base_color_map)
		var mt := _find_matching_texture(mat_key, metallic_map)
		var rg := _find_matching_texture(mat_key, roughness_map)
		var nm := _find_matching_texture(mat_key, normal_map_map)
		if bc.is_empty() and mt.is_empty() and rg.is_empty() and nm.is_empty():
			LogHelper.log("Skipping material (no matching textures): " + raw_name)
			continue

		LogHelper.log("Configuring material: " + raw_name)
		_configure_pbr_material(mat3d, bc, mt, rg, nm, texture_cache)

		ResourceSaver.save(mat3d, res_path)
		configured += 1

	if configured > 0:
		LogHelper.log("Configured %d material(s) with PBR textures" % configured)


## Apply surface material overrides on all MeshInstance3D nodes under root.
static func apply_surface_material_overrides(root: Node, texture_maps: Dictionary,
		texture_cache: Dictionary) -> void:
	var base_color_map: Dictionary = texture_maps.get("base_color", {})
	var metallic_map: Dictionary = texture_maps.get("metallic", {})
	var roughness_map: Dictionary = texture_maps.get("roughness", {})
	var normal_map_map: Dictionary = texture_maps.get("normal", {})
	if base_color_map.is_empty() and metallic_map.is_empty() and roughness_map.is_empty() and normal_map_map.is_empty():
		return

	var configured := _apply_overrides_recursive(root, base_color_map,
			metallic_map, roughness_map, normal_map_map, texture_cache)

	if configured > 0:
		LogHelper.log("Configured %d surface material override(s) with PBR textures" % configured)

# ————— impl —————

static func _apply_overrides_recursive(node: Node, base_color_map: Dictionary,
		metallic_map: Dictionary, roughness_map: Dictionary, normal_map_map: Dictionary,
		texture_cache: Dictionary) -> int:
	var configured := 0
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var mesh := mesh_instance.mesh
		if mesh != null:
			for surface_index in range(mesh.get_surface_count()):
				var candidates := _build_surface_texture_candidates(mesh_instance, surface_index)
				var bc := _find_matching_texture_for_candidates(candidates, base_color_map)
				var mt := _find_matching_texture_for_candidates(candidates, metallic_map)
				var rg := _find_matching_texture_for_candidates(candidates, roughness_map)
				var nm := _find_matching_texture_for_candidates(candidates, normal_map_map)
				if bc.is_empty() and mt.is_empty() and rg.is_empty() and nm.is_empty():
					# Always ensure a valid override so the renderer never receives an
					# uninitialized FBX-embedded material RID.
					if mesh_instance.get_surface_override_material(surface_index) == null:
						var existing := mesh.surface_get_material(surface_index)
						var fresh: StandardMaterial3D
						if existing is StandardMaterial3D:
							fresh = (existing as StandardMaterial3D).duplicate()
						else:
							fresh = StandardMaterial3D.new()
						fresh.resource_local_to_scene = true
						mesh_instance.set_surface_override_material(surface_index, fresh)
					continue

				var override_material := _build_surface_override_material(mesh_instance, surface_index)
				_configure_pbr_material(override_material, bc, mt, rg, nm, texture_cache)
				override_material.resource_local_to_scene = true
				mesh_instance.set_surface_override_material(surface_index, override_material)
				configured += 1

	for child in node.get_children():
		configured += _apply_overrides_recursive(child, base_color_map,
				metallic_map, roughness_map, normal_map_map, texture_cache)
	return configured


static func _configure_pbr_material(mat3d: StandardMaterial3D, bc: String, mt: String,
		rg: String, nm: String, texture_cache: Dictionary) -> void:
	mat3d.emission_enabled = false
	mat3d.emission = Color.BLACK

	if not bc.is_empty():
		var base_color_texture := _get_cached_texture(bc, texture_cache)
		if base_color_texture:
			mat3d.albedo_texture = base_color_texture
			mat3d.albedo_color = Color.WHITE
			LogHelper.log("  - Applied Base Color: " + bc.get_file())

	if not mt.is_empty():
		var metallic_texture := _get_cached_texture(mt, texture_cache)
		if metallic_texture:
			mat3d.metallic_texture = metallic_texture
			mat3d.metallic = 1.0
			mat3d.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			LogHelper.log("  - Applied Metallic: " + mt.get_file())

	if not rg.is_empty():
		var roughness_texture := _get_cached_texture(rg, texture_cache)
		if roughness_texture:
			mat3d.roughness_texture = roughness_texture
			mat3d.roughness = 1.0
			mat3d.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			LogHelper.log("  - Applied Roughness: " + rg.get_file())

	if not nm.is_empty():
		var normal_texture := _get_cached_texture(nm, texture_cache)
		if normal_texture:
			mat3d.normal_enabled = true
			mat3d.normal_texture = normal_texture
			mat3d.normal_scale = 1.0
			LogHelper.log("  - Applied Normal Map: " + nm.get_file())
static func _build_surface_override_material(mesh_instance: MeshInstance3D,
		surface_index: int) -> StandardMaterial3D:
	var existing_override := mesh_instance.get_surface_override_material(surface_index)
	if existing_override is StandardMaterial3D:
		return existing_override as StandardMaterial3D

	var source_material := mesh_instance.mesh.surface_get_material(surface_index)
	if source_material is StandardMaterial3D:
		return (source_material as StandardMaterial3D).duplicate() as StandardMaterial3D

	return StandardMaterial3D.new()

static func _build_surface_texture_candidates(mesh_instance: MeshInstance3D,
		surface_index: int) -> Array[String]:
	var candidates: Array[String] = []
	_add_texture_candidate(candidates, mesh_instance.name)
	_add_texture_candidate(candidates, mesh_instance.mesh.surface_get_name(surface_index))

	var surface_material := mesh_instance.mesh.surface_get_material(surface_index)
	if surface_material != null:
		_add_texture_candidate(candidates, _get_resource_match_name(surface_material))

	var parent := mesh_instance.get_parent()
	if parent != null:
		_add_texture_candidate(candidates, parent.name)

	return candidates

static func _add_texture_candidate(candidates: Array[String], raw_name: String) -> void:
	if raw_name.is_empty():
		return
	var normalized := _normalize_part_key(raw_name)
	if normalized.is_empty() or candidates.has(normalized):
		return
	candidates.append(normalized)

static func _get_resource_match_name(resource: Resource) -> String:
	if not resource.resource_name.is_empty():
		return resource.resource_name
	if not resource.resource_path.is_empty():
		return resource.resource_path.get_file().get_basename()
	return ""

static func _find_matching_texture_for_candidates(candidates: Array[String], textures: Dictionary) -> String:
	for candidate in candidates:
		var match := _find_matching_texture(candidate, textures)
		if not match.is_empty():
			return match
	return _find_matching_texture("", textures)

static func _find_matching_texture(material_name: String, textures: Dictionary) -> String:
	if textures.has(material_name):
		return textures[material_name]
	if textures.size() == 1:
		return textures.values()[0]
	return ""

static func _get_cached_texture(texture_path: String, texture_cache: Dictionary) -> Texture2D:
	if texture_cache.has(texture_path):
		return texture_cache[texture_path]

	var texture = load(texture_path) as Texture2D
	if texture:
		texture_cache[texture_path] = texture
	return texture

static func _extract_part_key(file_name: String, suffixes: Array) -> String:
	var key := file_name
	for suffix in suffixes:
		if key.ends_with(suffix):
			key = key.left(key.length() - suffix.length())
			break
	return key

static func _normalize_part_key(key: String) -> String:
	if key.is_empty():
		return key
	var k := key.to_lower()
	k = _extract_part_key(k, ["_basecolor", "basecolor", "_albedo", "albedo", "_diffuse", "diffuse"])
	k = _extract_part_key(k, ["_normal", "normal", "_metallic", "metallic", "_roughness", "roughness"])
	return k if not k.is_empty() else key.to_lower()
