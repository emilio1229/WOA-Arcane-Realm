# import_file_utils.gd
# Static file-system utilities for the model import pipeline
@tool
class_name ImportFileUtils
extends RefCounted

const MAX_CLEANUP_RETRIES: int = 5

# ————— pub api —————

## Locate the first model file (fbx > glb > gltf > obj) under directory.
static func find_model_file(directory: String) -> String:
	var dir := DirAccess.open(directory)
	if dir == null:
		return ""
	dir.include_hidden = false
	for ext in ["fbx", "glb", "gltf", "obj"]:
		var found := _find_file_recursive(directory, ext)
		if not found.is_empty():
			return found
	return ""

## Recursively list all files under directory (absolute paths).
static func list_files_recursive(directory: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(directory)
	if dir == null:
		return result
	dir.include_hidden = false
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := directory.path_join(entry)
		if dir.current_is_dir():
			result.append_array(list_files_recursive(full))
		else:
			result.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return result

## Move all contents of src into dst (files are renamed, dirs are merged).
static func move_dir_contents(src: String, dst: String) -> void:
	var dir := DirAccess.open(src)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var src_path := src.path_join(entry)
		var dst_path := dst.path_join(entry)
		if dir.current_is_dir():
			DirAccess.make_dir_recursive_absolute(dst_path)
			move_dir_contents(src_path, dst_path)
		else:
			DirAccess.rename_absolute(src_path, dst_path)
		entry = dir.get_next()
	dir.list_dir_end()

## Copy all contents of src into dst.
static func copy_dir_contents(src: String, dst: String) -> void:
	var dir := DirAccess.open(src)
	if dir == null:
		return
	dir.include_hidden = false
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var src_path := src.path_join(entry)
		var dst_path := dst.path_join(entry)
		if dir.current_is_dir():
			DirAccess.make_dir_recursive_absolute(dst_path)
			copy_dir_contents(src_path, dst_path)
		else:
			var bytes := FileAccess.get_file_as_bytes(src_path)
			var f := FileAccess.open(dst_path, FileAccess.WRITE)
			if f:
				f.store_buffer(bytes)
				f.close()
		entry = dir.get_next()
	dir.list_dir_end()

## Recursively delete a directory. Returns OK on success.
static func delete_dir_recursive(path: String) -> Error:
	var dir := DirAccess.open(path)
	if dir == null:
		return ERR_CANT_OPEN
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := path.path_join(entry)
		if dir.current_is_dir():
			delete_dir_recursive(full)
		else:
			DirAccess.remove_absolute(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return DirAccess.remove_absolute(path)

## Try to clean up a temp directory with retries.
static func cleanup_temp_dir(temp_path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(temp_path)
	if not DirAccess.dir_exists_absolute(abs_path):
		return
	for i in range(MAX_CLEANUP_RETRIES):
		if delete_dir_recursive(abs_path) == OK:
			LogHelper.log("Temporary files cleaned up")
			return
		OS.delay_msec(100)
	LogHelper.warning("Could not fully clean temp directory: " + temp_path)

# ————— internal —————

static func _find_file_recursive(directory: String, extension: String) -> String:
	var dir := DirAccess.open(directory)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := directory.path_join(entry)
		if dir.current_is_dir():
			var sub := _find_file_recursive(full, extension)
			if not sub.is_empty():
				dir.list_dir_end()
				return sub
		elif entry.get_extension().to_lower() == extension:
			dir.list_dir_end()
			return full
		entry = dir.get_next()
	dir.list_dir_end()
	return ""
