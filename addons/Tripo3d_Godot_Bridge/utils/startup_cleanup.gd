# startup_cleanup.gd
# Cleans up abandoned temp files on plugin load (once per 24 hours)
@tool
class_name StartupCleanup

const CACHE_FILE: String = "user://tripo_bridge_cache.cfg"
const CLEANUP_INTERVAL_HOURS: float = 24.0
const TEMP_DIR: String = "user://tripo_temp"

static func run() -> void:
	var last_str: String = _read_last_cleanup()

	if not last_str.is_empty():
		var last := Time.get_unix_time_from_datetime_string(last_str)
		var now := Time.get_unix_time_from_system()
		if (now - last) / 3600.0 < CLEANUP_INTERVAL_HOURS:
			return  # Not yet 24 hours

	_cleanup_temp()

	var now_str := Time.get_datetime_string_from_system(false)
	_write_last_cleanup(now_str)

	# Remove legacy ProjectSettings entry if present
	if ProjectSettings.has_setting("tripo_bridge/last_cleanup"):
		ProjectSettings.set_setting("tripo_bridge/last_cleanup", null)
		ProjectSettings.save()

static func _read_last_cleanup() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(ProjectSettings.globalize_path(CACHE_FILE)) != OK:
		return ""
	return cfg.get_value("cleanup", "last", "")

static func _write_last_cleanup(value: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(ProjectSettings.globalize_path(CACHE_FILE))
	cfg.set_value("cleanup", "last", value)
	cfg.save(ProjectSettings.globalize_path(CACHE_FILE))

static func _cleanup_temp() -> void:
	var abs_temp := ProjectSettings.globalize_path(TEMP_DIR)
	if not DirAccess.dir_exists_absolute(abs_temp):
		return
	LogHelper.log("StartupCleanup: cleaning old temp files...")
	_delete_dir_recursive(abs_temp)
	LogHelper.log("StartupCleanup: done")

static func _delete_dir_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_delete_dir_recursive(full)
		else:
			DirAccess.remove_absolute(full)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
