# tripo_bridge_plugin.gd
# Godot EditorPlugin entry point for Tripo3D Bridge
@tool
extends EditorPlugin

# 在 @tool EditorPlugin 中，class_name 对 .new() 不可靠（加载期注册表可能未就绪）。
# 解决方案：每个需要 .new() 的类单独用 preload 小写私有别名，
# 静态方法调用（如 LogHelper.log()）仍用 class_name。
const _Server = preload("res://addons/Tripo3d_Godot_Bridge/network/websocket_server.gd")
const _Dock   = preload("res://addons/Tripo3d_Godot_Bridge/ui/tripo_bridge_dock.gd")
const _Importer = preload("res://addons/Tripo3d_Godot_Bridge/importing/model_importer.gd")
const _Converter = preload("res://addons/Tripo3d_Godot_Bridge/converting/asset_converter.gd")

var _server = null
var _dock = null
var _importer = null
var _plugin_dir: String
var _active_import: Dictionary = {}
var _prepare_thread: Thread = null
var _prepare_request: Dictionary = {}
var _scan_wait_progress: float = 0.0
var _is_waiting_for_scan: bool = false
var _scan_wait_elapsed: float = 0.0
var _forced_scan_requested: bool = false

# Progress phase boundaries (continuous 0→1 bar)
const PHASE_TRANSFER_END: float = 0.2
const PHASE_PREPARE_END: float = 0.5
const PHASE_SCAN_END: float = 0.8
# finalize occupies PHASE_SCAN_END → 1.0
const SCAN_TICK_SPEED: float = 0.02        # progress bar creep speed (units/sec) during scan-wait
const AUTO_SCAN_RETRY_SECONDS: float = 8.0 # if EditorFS still hasn't started after this many seconds, retry scan_sources

func _enter_tree() -> void:
	_plugin_dir = get_script().get_path().get_base_dir()

	# Run startup cleanup
	StartupCleanup.run()

	# Create server
	_server = _Server.new()
	_server.connection_status_changed.connect(_on_connection_status_changed)
	_server.server_start_failed.connect(_on_server_start_failed)
	_server.progress_updated.connect(_on_transfer_progress)
	_server.file_transfer_started.connect(_on_file_transfer_started)
	_server.file_transfer_completed.connect(_on_file_transfer_completed)

	# Create dock
	_dock = _Dock.new()
	_dock.name = "Tripo Bridge"
	_dock.setup(_plugin_dir)
	_dock.start_server_pressed.connect(_on_start_server)
	_dock.stop_server_pressed.connect(_on_stop_server)

	# Connect log helper
	LogHelper.get_instance().logged.connect(_on_log)
	var efs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	efs.resources_reimporting.connect(_on_resources_reimporting)
	efs.resources_reimported.connect(_on_resources_reimported)
	efs.filesystem_changed.connect(_on_filesystem_changed)

	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _dock)

	# Connect converter panel
	var converter_panel = _dock.get_converter_panel()
	if converter_panel:
		converter_panel.convert_requested.connect(_on_convert_requested)

	# Auto-start server
	_start_server()

func _exit_tree() -> void:
	_wait_for_prepare_thread()

	if _server:
		_server.stop()
		_server = null

	var efs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if efs.resources_reimporting.is_connected(_on_resources_reimporting):
		efs.resources_reimporting.disconnect(_on_resources_reimporting)
	if efs.resources_reimported.is_connected(_on_resources_reimported):
		efs.resources_reimported.disconnect(_on_resources_reimported)
	if efs.filesystem_changed.is_connected(_on_filesystem_changed):
		efs.filesystem_changed.disconnect(_on_filesystem_changed)

	var logger = LogHelper.get_instance()
	if logger.logged.is_connected(_on_log):
		logger.logged.disconnect(_on_log)
	LogHelper.release_instance()

	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null

func _process(delta: float) -> void:
	if _server:
		_server.poll()
	_poll_prepare_thread()
	# Slowly tick progress bar while waiting for Godot filesystem scan
	if _is_waiting_for_scan and _dock:
		_scan_wait_progress = minf(_scan_wait_progress + SCAN_TICK_SPEED * delta, PHASE_SCAN_END)
		_dock.update_progress(_scan_wait_progress)
		_scan_wait_elapsed += delta
		_maybe_force_filesystem_scan()

# --- Server control ---

func _start_server() -> void:
	if _server:
		_server.start()
		if _dock:
			_dock.set_server_running(_server.is_running)
			if _server.is_running:
				_dock.show_server_error("")

func _stop_server() -> void:
	if _server:
		_server.stop()
		if _dock:
			_dock.set_server_running(false)

func _on_start_server() -> void:
	_start_server()

func _on_stop_server() -> void:
	_stop_server()

# --- Signal handlers ---

func _on_connection_status_changed(connected: bool) -> void:
	if _dock:
		_dock.update_connection(connected)

func _on_server_start_failed(error_code: int) -> void:
	if _dock == null:
		return
	var status_key: int = TripoBridgeLocalization.Key.START_FAILED
	if error_code == ERR_ALREADY_IN_USE:
		status_key = TripoBridgeLocalization.Key.PORT_IN_USE
	_dock.set_server_running(false)
	_dock.show_server_error(TripoBridgeLocalization.get_text(status_key))

func _on_transfer_progress(progress: float) -> void:
	# Transfer phase: 0 → PHASE_TRANSFER_END
	if _dock:
		_dock.update_progress(progress * PHASE_TRANSFER_END)

func _on_import_progress(progress: float) -> void:
	# Import sub-progress mapped to the appropriate phase
	if _dock:
		var mapped: float
		if progress <= 0.5:
			# prepare_import phase: PHASE_TRANSFER_END → PHASE_PREPARE_END
			mapped = PHASE_TRANSFER_END + (progress / 0.5) * (PHASE_PREPARE_END - PHASE_TRANSFER_END)
		else:
			# finalize_import phase: PHASE_SCAN_END → 1.0
			var t := (progress - 0.5) / 0.5  # normalize 0.5-1.0 → 0-1
			mapped = PHASE_SCAN_END + t * (1.0 - PHASE_SCAN_END)
		_dock.update_progress(mapped)

func _on_file_transfer_started(file_id: String, file_name: String,
		chunk_index: int, chunk_total: int) -> void:
	if _dock:
		_dock.update_file(file_name)
		_dock.update_progress(0.0)

func _on_file_transfer_completed(file_id: String, file_name: String,
		file_type: String) -> void:
	if not _active_import.is_empty() or _is_prepare_running():
		LogHelper.warning("An import is already in progress")
		if _server:
			_server.take_completed_transfer(file_id)
			_server.send_import_result(file_id, false, "Another import is already in progress")
		return

	if _server == null:
		return

	var transfer_session: Dictionary = _server.take_completed_transfer(file_id)
	if transfer_session.is_empty():
		LogHelper.error("Transfer session missing for completed file: " + file_id)
		_finish_import(file_id, false, "Import failed")
		return

	_start_prepare_import(file_id, transfer_session)

func _start_prepare_import(file_id: String, transfer_session: Dictionary) -> void:
	LogHelper.log("Preparing import files in background...")
	_prepare_request = {
		"file_id": file_id,
		"file_name": String(transfer_session.get("file_name", "")),
	}
	if _dock:
		_dock.update_progress(PHASE_TRANSFER_END)

	_prepare_thread = Thread.new()
	var err: int = _prepare_thread.start(Callable(self, "_run_prepare_import").bind(file_id, transfer_session))
	if err != OK:
		_prepare_thread = null
		_prepare_request.clear()
		LogHelper.error("Failed to start background prepare worker: " + str(err))
		_finish_import(file_id, false, "Import failed")

func _run_prepare_import(file_id: String, transfer_session: Dictionary) -> Dictionary:
	var importer = _Importer.new()
	return {
		"file_id": file_id,
		"info": importer.prepare_import_from_transfer_session(file_id, transfer_session),
	}

func _poll_prepare_thread() -> void:
	if _prepare_thread == null:
		return
	if _prepare_thread.is_alive():
		return

	var result: Variant = _prepare_thread.wait_to_finish()
	_prepare_thread = null

	var file_id: String = String(_prepare_request.get("file_id", ""))
	_prepare_request.clear()
	if not result is Dictionary:
		_finish_import(file_id, false, "Import failed")
		return

	var info: Dictionary = result.get("info", {})
	if info.is_empty():
		LogHelper.error("Background import preparation failed")
		_finish_import(file_id, false, "Import failed")
		return

	_complete_prepare_import(file_id, info)

func _complete_prepare_import(file_id: String, info: Dictionary) -> void:
	_importer = _Importer.new()
	_importer.progress_updated.connect(func(p): _on_import_progress(p))
	_active_import = info.duplicate(true)
	_active_import["file_id"] = file_id

	LogHelper.log("Background file preparation complete")
	# Enter scan-wait phase: show log and slowly tick progress
	LogHelper.log("Waiting for Godot to import resources...")
	_scan_wait_progress = PHASE_PREPARE_END
	_is_waiting_for_scan = true
	_scan_wait_elapsed = 0.0
	_forced_scan_requested = false

	# Files are on disk — trigger scan_sources immediately so EditorFileSystem
	# picks them up without waiting for the next auto-scan cycle.
	call_deferred("_run_forced_filesystem_scan")

func _wait_for_prepare_thread() -> void:
	if _prepare_thread == null:
		return
	if _prepare_thread.is_started():
		_prepare_thread.wait_to_finish()
	_prepare_thread = null
	_prepare_request.clear()

func _is_prepare_running() -> bool:
	return _prepare_thread != null

func _on_resources_reimporting(_resources: PackedStringArray) -> void:
	pass # signal connected to suppress Godot's double-scan warning

func _on_resources_reimported(resources: PackedStringArray) -> void:
	if _active_import.is_empty() or _importer == null:
		return

	var model_res_path := String(_active_import["asset_path"]).path_join(
			String(_active_import["model_file_name"]))
	if model_res_path not in resources:
		return

	_do_finalize()

# Fallback: catches cases where resources_reimported did not include our path
# (e.g. Godot merged it into a broader scan).
func _on_filesystem_changed() -> void:
	if _active_import.is_empty() or _importer == null:
		return
	var efs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	var model_res_path := String(_active_import["asset_path"]).path_join(
			String(_active_import["model_file_name"]))
	if efs.is_scanning():
		return
	if _editor_filesystem_is_importing(efs):
		return
	if not _is_model_resource_ready(model_res_path):
		return

	_do_finalize()

func _do_finalize() -> void:
	_is_waiting_for_scan = false
	LogHelper.log("Asset imported successfully")
	var success: bool = _importer.finalize_import(
			_active_import["asset_path"], _active_import["model_file_name"],
			_active_import["model_name"], _active_import["temp_path"])
	var msg: String = "Model imported successfully" if success else "Import failed"
	LogHelper.log(msg)
	_finish_import(String(_active_import["file_id"]), success, msg)

func _finish_import(file_id: String, success: bool, message: String) -> void:
	if _server and not file_id.is_empty():
		_server.send_import_result(file_id, success, message)
	_importer = null
	_active_import.clear()
	_is_waiting_for_scan = false
	_scan_wait_elapsed = 0.0
	_forced_scan_requested = false

func _on_log(message: String) -> void:
	if _dock:
		_dock.add_log(message)

func _get_active_model_res_path() -> String:
	if _active_import.is_empty():
		return ""
	return String(_active_import["asset_path"]).path_join(
			String(_active_import["model_file_name"]))

func _maybe_force_filesystem_scan() -> void:
	# Retry fallback: if EditorFS is still idle after AUTO_SCAN_RETRY_SECONDS,
	# the initial scan_sources may have been dropped — fire it again once.
	if not _is_waiting_for_scan or _active_import.is_empty() or _forced_scan_requested:
		return
	if _scan_wait_elapsed < AUTO_SCAN_RETRY_SECONDS:
		return

	var efs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	var model_res_path := _get_active_model_res_path()
	if efs.is_scanning() or _editor_filesystem_is_importing(efs) or _is_model_resource_ready(model_res_path):
		return

	_forced_scan_requested = true
	LogHelper.log("EditorFS still idle after %.0fs — retrying scan_sources" % _scan_wait_elapsed)
	call_deferred("_run_forced_filesystem_scan")

func _run_forced_filesystem_scan() -> void:
	if not _is_waiting_for_scan or _active_import.is_empty():
		return
	var efs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	efs.scan_sources()

func _editor_filesystem_is_importing(efs: EditorFileSystem) -> bool:
	if efs == null or not efs.has_method("is_importing"):
		return false
	return efs.is_importing()

func _is_model_resource_ready(model_res_path: String) -> bool:
	if not ResourceLoader.exists(model_res_path):
		return false
	var model_resource: Resource = ResourceLoader.load(model_res_path, "", ResourceLoader.CACHE_MODE_REUSE)
	return model_resource is PackedScene or model_resource is Mesh

func _on_convert_requested(source_dir: String, category: String, friendly_name: String) -> void:
	LogHelper.log("Converting: %s -> Assets/%s/%s" % [source_dir.get_file(), category, friendly_name])
	var success := TripoAssetConverter.convert_model(source_dir, category, friendly_name)
	var converter_panel = _dock.get_converter_panel() if _dock else null
	if success:
		LogHelper.log(TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.CONVERT_SUCCESS)
			+ ": " + friendly_name)
		if converter_panel:
			converter_panel.set_status(
				TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.CONVERT_SUCCESS)
				+ ": " + friendly_name)
	else:
		LogHelper.error(TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.CONVERT_FAILED)
			+ ": " + friendly_name)
		if converter_panel:
			converter_panel.set_status(
				TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.CONVERT_FAILED)
				+ ": " + friendly_name, true)
