# model_importer.gd
# Orchestrates ZIP/FBX/GLB extraction, Godot import, and scene placement
@tool
extends RefCounted

# ————— config —————

const IMPORT_FOLDER: String = "res://TripoModels"
const TEMP_DIR: String = "user://tripo_temp"
const MAX_UNIQUE_NAME_ATTEMPTS: int = 1000

# ————— exported —————

signal progress_updated(progress: float)

var _should_emit_progress: bool = true
var _should_log: bool = true

# ————— pub api —————

# Phase 1 (synchronous): extract, rename, and move files to res://.
# Returns a dictionary with import state on success, or an empty dict on failure.
# The caller is responsible for triggering EditorFileSystem.scan() and waiting
# for filesystem_changed before calling finalize_import().
func prepare_import(file_id: String, file_name: String, file_type: String,
		file_data: PackedByteArray) -> Dictionary:
	_set_prepare_mode(true, true)
	return _prepare_import_impl(file_id, file_name, file_type, file_data)

func prepare_import_background(file_id: String, file_name: String, file_type: String,
		file_data: PackedByteArray) -> Dictionary:
	_set_prepare_mode(false, false)
	return _prepare_import_impl(file_id, file_name, file_type, file_data)

func prepare_import_from_transfer_session(file_id: String,
		transfer_session: Dictionary) -> Dictionary:
	var file_name: String = String(transfer_session.get("file_name", ""))
	var file_type: String = String(transfer_session.get("file_type", ""))
	var file_data: PackedByteArray = FileTransferManager.assemble_session_data(
			transfer_session, file_id)
	if file_data.is_empty():
		return {}
	return prepare_import_background(file_id, file_name, file_type, file_data)

func _prepare_import_impl(file_id: String, file_name: String, file_type: String,
		file_data: PackedByteArray) -> Dictionary:
	LogHelper.log("Starting import process...", _should_log)
	_emit_prepare_progress(0.0)

	var is_zip := file_type.to_lower() == "zip" or file_name.to_lower().ends_with(".zip")
	var temp_path := TEMP_DIR.path_join(file_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_path))

	var model_path: String = ""
	if is_zip:
		model_path = _process_zip_file(file_id, file_name, file_data, temp_path)
	else:
		model_path = _process_direct_file(file_id, file_name, file_type, file_data, temp_path)

	if model_path.is_empty():
		LogHelper.log("Error: Could not locate model file", _should_log)
		ImportFileUtils.cleanup_temp_dir(temp_path)
		return {}

	_emit_prepare_progress(0.3)

	# Determine unique model name
	var model_name := _get_unique_model_name(_get_clean_model_name(file_name))
	var model_ext := model_path.get_extension()
	var model_dir := model_path.get_base_dir()

	# Rename model file in temp to unique name
	var renamed_path := model_dir.path_join(model_name + "." + model_ext)
	if model_path != renamed_path:
		DirAccess.rename_absolute(
				ProjectSettings.globalize_path(model_path),
				ProjectSettings.globalize_path(renamed_path))
		model_path = renamed_path

	# NOTE: The .fbm texture folder is intentionally NOT renamed.
	# The FBX binary embeds texture paths using the original folder name;
	# renaming it breaks Godot's FBX importer texture resolution.

	# Move to res://TripoModels/
	var asset_path := _move_to_res_folder(model_name, temp_path)
	if asset_path.is_empty():
		LogHelper.log("Error: Failed to move files to project folder", _should_log)
		ImportFileUtils.cleanup_temp_dir(temp_path)
		return {}

	_emit_prepare_progress(0.5)

	return {
		"asset_path": asset_path,
		"model_file_name": model_name + "." + model_ext,
		"model_name": model_name,
		"temp_path": temp_path,
	}

# Phase 2 (synchronous): apply PBR textures to imported materials.
# Must be called after the filesystem scan completes.
func finalize_import(asset_path: String, model_file_name: String,
		model_name: String, temp_path: String) -> bool:
	var model_res_path := asset_path.path_join(model_file_name)
	if not ResourceLoader.exists(model_res_path):
		LogHelper.error("Import failed: resource not available after scan: " + model_res_path)
		ImportFileUtils.cleanup_temp_dir(temp_path)
		return false

	progress_updated.emit(0.7)

	var asset_files: Array[String] = ImportFileUtils.list_files_recursive(
			ProjectSettings.globalize_path(asset_path))
	var texture_maps: Dictionary = TripoTextureApplicator.collect_texture_maps(asset_path, asset_files)
	var texture_cache: Dictionary = {}

	TripoTextureApplicator.apply_textures_to_materials(
			asset_path, asset_files, texture_maps, texture_cache)

	progress_updated.emit(1.0)
	ImportFileUtils.cleanup_temp_dir(temp_path)
	return true

# ————— impl —————

func _process_zip_file(file_id: String, file_name: String,
		file_data: PackedByteArray, temp_path: String) -> String:
	LogHelper.log("Extracting ZIP file...", _should_log)
	var zip_file := FileAccess.open(ProjectSettings.globalize_path(
			temp_path.path_join("archive.zip")), FileAccess.WRITE)
	if zip_file == null:
		LogHelper.error("Could not write ZIP to temp: " + str(FileAccess.get_open_error()), _should_log)
		return ""
	zip_file.store_buffer(file_data)
	zip_file.close()

	# Extract
	var extract_path := temp_path.path_join("extracted")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(extract_path))
	var reader := ZIPReader.new()
	var err := reader.open(ProjectSettings.globalize_path(temp_path.path_join("archive.zip")))
	if err != OK:
		LogHelper.error("ZIPReader open error: " + str(err), _should_log)
		return ""
	for entry in reader.get_files():
		if entry.ends_with("/"):
			continue
		var entry_data := reader.read_file(entry)
		var out_path := ProjectSettings.globalize_path(extract_path.path_join(entry))
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f:
			f.store_buffer(entry_data)
			f.close()
	reader.close()

	# Delete ZIP
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path.path_join("archive.zip")))

	# Find model file
	var model_file: String = ImportFileUtils.find_model_file(
			ProjectSettings.globalize_path(extract_path))
	if model_file.is_empty():
		LogHelper.log("Error: No FBX/OBJ/GLB file found in ZIP", _should_log)
		return ""
	LogHelper.log("Found model: " + model_file.get_file(), _should_log)

	# Flatten: move only the model's parent directory contents into temp_path.
	# This handles ZIPs that wrap everything in a top-level subdirectory.
	var model_parent_abs: String = model_file.get_base_dir()
	ImportFileUtils.move_dir_contents(model_parent_abs,
			ProjectSettings.globalize_path(temp_path))

	# Remove the now-empty extract dir
	ImportFileUtils.delete_dir_recursive(ProjectSettings.globalize_path(extract_path))

	return temp_path.path_join(model_file.get_file())

func _process_direct_file(file_id: String, file_name: String, file_type: String,
		file_data: PackedByteArray, temp_path: String) -> String:
	LogHelper.log("Processing %s file..." % file_type.to_upper(), _should_log)
	var ext := file_type if file_type.begins_with(".") else ("." + file_type)
	var out_path := temp_path.path_join(file_name + ext)
	var f := FileAccess.open(ProjectSettings.globalize_path(out_path), FileAccess.WRITE)
	if f == null:
		LogHelper.error("Could not write file: " + str(FileAccess.get_open_error()), _should_log)
		return ""
	f.store_buffer(file_data)
	f.close()
	return out_path

func _get_clean_model_name(file_name: String) -> String:
	var name := file_name if file_name else "model"
	for ext in [".zip", ".fbx", ".obj", ".glb", ".gltf"]:
		if name.to_lower().ends_with(ext):
			name = name.left(name.length() - ext.length())
			break
	name = name.strip_edges()
	if name.is_empty():
		name = "model"
	return name.replace(" ", "_")

func _get_unique_model_name(base_name: String) -> String:
	var candidate := base_name
	var folder := IMPORT_FOLDER.path_join(candidate)
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
		return candidate
	var idx := 1
	while idx <= MAX_UNIQUE_NAME_ATTEMPTS:
		candidate = "%s_%d" % [base_name, idx]
		folder = IMPORT_FOLDER.path_join(candidate)
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
			LogHelper.log("Model already exists, importing as: " + candidate, _should_log)
			return candidate
		idx += 1
	var fallback := _make_timestamped_name(base_name)
	LogHelper.warning("Unique model name attempts exceeded, falling back to: " + fallback, _should_log)
	return fallback

func _move_to_res_folder(model_name: String, temp_path: String) -> String:
	LogHelper.log("Moving to project folder...", _should_log)
	var asset_folder := IMPORT_FOLDER.path_join(model_name)
	var asset_abs := ProjectSettings.globalize_path(asset_folder)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(IMPORT_FOLDER))
	DirAccess.make_dir_recursive_absolute(asset_abs)
	ImportFileUtils.copy_dir_contents(ProjectSettings.globalize_path(temp_path), asset_abs)
	return asset_folder

func _set_prepare_mode(emit_progress: bool, emit_logs: bool) -> void:
	_should_emit_progress = emit_progress
	_should_log = emit_logs

func _emit_prepare_progress(progress: float) -> void:
	if _should_emit_progress:
		progress_updated.emit(progress)

func _add_to_scene(asset_path: String, model_file_name: String, display_name: String,
		texture_maps: Dictionary, texture_cache: Dictionary) -> bool:
	LogHelper.log("Adding to scene...")
	var model_res_path := asset_path.path_join(model_file_name)

	var model_resource: Resource = ResourceLoader.load(model_res_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if model_resource == null:
		LogHelper.log("Error: Could not load imported resource")
		return false

	var instance: Node = null
	if model_resource is PackedScene:
		instance = (model_resource as PackedScene).instantiate()
	elif model_resource is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = model_resource as Mesh
		instance = mesh_instance
	else:
		LogHelper.log("Error: Unsupported imported resource type: " + model_resource.get_class())
		return false

	if instance == null:
		LogHelper.log("Error: Could not instantiate scene")
		return false

	TripoTextureApplicator.apply_surface_material_overrides(
			instance, texture_maps, texture_cache)

	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null:
		return _create_new_scene_with_instance(instance, asset_path, display_name)

	instance.name = _get_unique_node_name(root, display_name)
	root.add_child(instance)
	_assign_scene_ownership(instance, root, model_resource is PackedScene)
	if model_resource is PackedScene:
		root.set_editable_instance(instance, true)

	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(instance)
	EditorInterface.mark_scene_as_unsaved()

	LogHelper.log("Model added to scene: " + instance.name)
	return true

func _create_new_scene_with_instance(instance: Node, asset_path: String,
		display_name: String) -> bool:
	LogHelper.log("No active scene detected, creating a new 3D scene...")

	var scene_root := Node3D.new()
	scene_root.name = "Root3D"
	instance.name = display_name
	scene_root.add_child(instance)
	_assign_scene_ownership(instance, scene_root, instance.scene_file_path != "")
	if instance.scene_file_path != "":
		scene_root.set_editable_instance(instance, true)

	var packed_scene := PackedScene.new()
	var pack_err := packed_scene.pack(scene_root)
	if pack_err != OK:
		LogHelper.log("Error: Could not pack new scene: " + str(pack_err))
		scene_root.free()
		return false

	var scene_res_path := asset_path.path_join(display_name + ".tscn")
	var save_err := ResourceSaver.save(packed_scene, scene_res_path)
	scene_root.free()
	if save_err != OK:
		LogHelper.log("Error: Could not save new scene: " + str(save_err))
		return false

	EditorInterface.open_scene_from_path(scene_res_path)

	var opened_root: Node = EditorInterface.get_edited_scene_root()
	if opened_root != null:
		var added_node := opened_root.get_node_or_null(NodePath(display_name))
		if added_node != null:
			EditorInterface.get_selection().clear()
			EditorInterface.get_selection().add_node(added_node)

	LogHelper.log("Created new 3D scene and added model: " + display_name)
	return true

# ————— internal —————

func _assign_scene_ownership(node: Node, owner: Node,
		preserve_nested_instance_ownership: bool) -> void:
	node.owner = owner
	if preserve_nested_instance_ownership:
		return
	_set_owner_recursive(node, owner)

func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)

func _get_unique_node_name(parent: Node, base_name: String) -> String:
	if parent.get_node_or_null(NodePath(base_name)) == null:
		return base_name
	var idx := 1
	while idx <= MAX_UNIQUE_NAME_ATTEMPTS:
		var candidate := "%s_%d" % [base_name, idx]
		if parent.get_node_or_null(NodePath(candidate)) == null:
			return candidate
		idx += 1
	var fallback := _make_timestamped_name(base_name)
	LogHelper.warning("Unique node name attempts exceeded, falling back to: " + fallback)
	return fallback

func _make_timestamped_name(base_name: String) -> String:
	return "%s_%d" % [base_name, Time.get_ticks_msec()]
