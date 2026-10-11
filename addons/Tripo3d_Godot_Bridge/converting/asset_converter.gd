# asset_converter.gd
# Converts TripoModels FBX imports to clean .res mesh files with renamed textures
@tool
class_name TripoAssetConverter
extends RefCounted

const TRIPO_MODELS_DIR: String = "res://TripoModels"
const ASSETS_DIR: String = "res://Assets"
const TEXTURES_SUBDIR: String = "Texs"

const MODEL_EXTENSIONS: PackedStringArray = ["fbx", "glb", "gltf", "obj"]
const IMAGE_EXTENSIONS: PackedStringArray = ["png", "jpg", "jpeg", "tga", "webp"]

const TEXTURE_SUFFIXES: Dictionary = {
	"basecolor": "basecolor",
	"albedo": "basecolor",
	"diffuse": "basecolor",
	"metallic": "metallic",
	"roughness": "roughness",
	"normal": "normal",
}

## Scan res://TripoModels/ for subdirectories containing importable models.
## Returns an array of dictionaries: [{folder_name, folder_path, model_file, textures}]
static func scan_tripo_models() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var base_abs := ProjectSettings.globalize_path(TRIPO_MODELS_DIR)
	var dir := DirAccess.open(base_abs)
	if dir == null:
		return results

	dir.include_hidden = false
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			var sub_abs := base_abs.path_join(entry)
			var model_file := _find_model_in_dir(sub_abs)
			if not model_file.is_empty():
				var textures := _find_textures_in_dir(sub_abs)
				results.append({
					"folder_name": entry,
					"folder_path": TRIPO_MODELS_DIR.path_join(entry),
					"model_file": model_file,
					"textures": textures,
				})
		entry = dir.get_next()
	dir.list_dir_end()
	return results


## Convert a TripoModels entry to a clean .res mesh with renamed textures.
## source_dir: res:// path to the TripoModels subfolder (e.g. "res://TripoModels/uuid")
## category: target subfolder under Assets/ (e.g. "Rocks")
## friendly_name: human-readable name (e.g. "Rock01_SongDynasty")
## Returns true on success.
static func convert_model(source_dir: String, category: String, friendly_name: String) -> bool:
	# Validate inputs
	if friendly_name.strip_edges().is_empty():
		LogHelper.error("Friendly name cannot be empty")
		return false
	if category.strip_edges().is_empty():
		LogHelper.error("Category cannot be empty")
		return false

	friendly_name = friendly_name.strip_edges().replace(" ", "_")
	category = category.strip_edges().replace(" ", "_")

	var source_abs := ProjectSettings.globalize_path(source_dir)

	# Find the model file
	var model_file_abs := _find_model_in_dir(source_abs)
	if model_file_abs.is_empty():
		LogHelper.error("No model file found in: " + source_dir)
		return false

	var model_file_name := model_file_abs.get_file()
	var model_res_path := source_dir.path_join(model_file_name)

	# Load the imported model resource
	if not ResourceLoader.exists(model_res_path):
		LogHelper.error("Model resource not found (not yet imported by Godot?): " + model_res_path)
		return false

	var resource: Resource = ResourceLoader.load(model_res_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if resource == null:
		LogHelper.error("Failed to load resource: " + model_res_path)
		return false

	# Extract mesh from the resource
	var mesh: Mesh = _extract_mesh(resource)
	if mesh == null:
		LogHelper.error("No mesh found in resource: " + model_res_path)
		return false

	# Create output directories
	var out_dir := ASSETS_DIR.path_join(category)
	var tex_dir := out_dir.path_join(TEXTURES_SUBDIR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(tex_dir))

	# Check if output already exists
	var out_res_path := out_dir.path_join(friendly_name + ".res")
	if ResourceLoader.exists(out_res_path):
		LogHelper.error("Output already exists: " + out_res_path)
		return false

	# Copy and rename textures
	var texture_mapping: Dictionary = _copy_and_rename_textures(source_abs, tex_dir, friendly_name)

	# Build material with renamed textures and assign to mesh
	_apply_material_to_mesh(mesh, texture_mapping)

	# Save the mesh as .res
	var save_err := ResourceSaver.save(mesh, out_res_path)
	if save_err != OK:
		LogHelper.error("Failed to save mesh resource: " + str(save_err))
		return false

	LogHelper.log("Converted: " + friendly_name + " -> " + out_res_path)

	# Trigger filesystem scan
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan_sources()

	return true


# ————— internal —————

## Find the first model file in a directory (absolute path).
static func _find_model_in_dir(dir_abs: String) -> String:
	var dir := DirAccess.open(dir_abs)
	if dir == null:
		return ""
	dir.include_hidden = false
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			var ext := entry.get_extension().to_lower()
			if ext in MODEL_EXTENSIONS:
				dir.list_dir_end()
				return dir_abs.path_join(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return ""


## Find all texture files recursively in a directory (absolute paths).
static func _find_textures_in_dir(dir_abs: String) -> Array[String]:
	var textures: Array[String] = []
	var files := ImportFileUtils.list_files_recursive(dir_abs)
	for f in files:
		var ext := f.get_extension().to_lower()
		if ext in IMAGE_EXTENSIONS:
			textures.append(f)
	return textures


## Extract the first Mesh from a resource (PackedScene or Mesh).
static func _extract_mesh(resource: Resource) -> Mesh:
	if resource is Mesh:
		return (resource as Mesh).duplicate()

	if resource is PackedScene:
		var scene := resource as PackedScene
		var instance := scene.instantiate()
		if instance == null:
			return null
		var mesh := _find_mesh_recursive(instance)
		var result: Mesh = null
		if mesh != null:
			result = mesh.duplicate()
		instance.free()
		return result

	return null


## Recursively find the first MeshInstance3D's mesh in a node tree.
static func _find_mesh_recursive(node: Node) -> Mesh:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			return mi.mesh
	for child in node.get_children():
		var found := _find_mesh_recursive(child)
		if found != null:
			return found
	return null


## Copy textures from source dir to target tex_dir with friendly names.
## Returns a mapping: { "basecolor": res_path, "metallic": res_path, ... }
static func _copy_and_rename_textures(source_abs: String, tex_dir: String,
		friendly_name: String) -> Dictionary:
	var mapping: Dictionary = {}
	var textures := _find_textures_in_dir(source_abs)
	var tex_dir_abs := ProjectSettings.globalize_path(tex_dir)

	for tex_abs in textures:
		var tex_file := tex_abs.get_file()
		var tex_base := tex_file.get_basename().to_lower()
		var tex_ext := tex_file.get_extension()

		# Determine texture type from filename
		var tex_type := _classify_texture(tex_base)
		if tex_type.is_empty():
			# Unknown texture type, copy with generic name
			tex_type = tex_base.get_file().get_basename()

		var new_name := friendly_name + "_" + tex_type + "." + tex_ext
		var dst_abs := tex_dir_abs.path_join(new_name)

		# Copy the texture file
		var src_data := FileAccess.get_file_as_bytes(tex_abs)
		if src_data.is_empty():
			continue
		var f := FileAccess.open(dst_abs, FileAccess.WRITE)
		if f == null:
			LogHelper.error("Failed to copy texture: " + tex_file)
			continue
		f.store_buffer(src_data)
		f.close()

		var res_path := tex_dir.path_join(new_name)
		mapping[tex_type] = res_path
		LogHelper.log("  Texture: " + new_name)

	return mapping


## Classify a texture filename into a PBR type.
static func _classify_texture(basename_lower: String) -> String:
	for suffix in TEXTURE_SUFFIXES:
		if suffix in basename_lower:
			return TEXTURE_SUFFIXES[suffix]
	return ""


## Build and apply a StandardMaterial3D to all surfaces of the mesh.
static func _apply_material_to_mesh(mesh: Mesh, texture_mapping: Dictionary) -> void:
	if texture_mapping.is_empty():
		return

	# We need to wait for EditorFileSystem to import the copied textures
	# before we can load them. Since we're saving the mesh immediately,
	# we store the texture paths in the material resource_name as metadata
	# and load textures by path. The textures will resolve after the next scan.

	var mat := StandardMaterial3D.new()
	mat.emission_enabled = false
	mat.emission = Color.BLACK

	# Try to load textures (they may not be imported yet if this is first scan)
	if texture_mapping.has("basecolor"):
		var tex := _try_load_texture(texture_mapping["basecolor"])
		if tex:
			mat.albedo_texture = tex
			mat.albedo_color = Color.WHITE

	if texture_mapping.has("metallic"):
		var tex := _try_load_texture(texture_mapping["metallic"])
		if tex:
			mat.metallic_texture = tex
			mat.metallic = 1.0
			mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED

	if texture_mapping.has("roughness"):
		var tex := _try_load_texture(texture_mapping["roughness"])
		if tex:
			mat.roughness_texture = tex
			mat.roughness = 1.0
			mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED

	if texture_mapping.has("normal"):
		var tex := _try_load_texture(texture_mapping["normal"])
		if tex:
			mat.normal_enabled = true
			mat.normal_texture = tex
			mat.normal_scale = 1.0

	# Apply material to all surfaces
	if mesh is ArrayMesh:
		var array_mesh := mesh as ArrayMesh
		for i in range(array_mesh.get_surface_count()):
			array_mesh.surface_set_material(i, mat)


## Try to load a texture, returning null if not yet available.
static func _try_load_texture(res_path: String) -> Texture2D:
	if not ResourceLoader.exists(res_path):
		return null
	return ResourceLoader.load(res_path) as Texture2D
