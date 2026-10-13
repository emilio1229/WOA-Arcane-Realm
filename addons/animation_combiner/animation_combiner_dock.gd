@tool
extends Control

const DEFAULT_BLENDER_EXECUTABLE: String = ""

# UI References
@onready var base_model_path_edit: LineEdit = %BaseModelPathEdit
@onready var base_model_row: HBoxContainer = %BaseModelRow
@onready var browse_base_model_btn: Button = %BrowseBaseModelBtn
@onready var clear_base_model_btn: Button = %ClearBaseModelBtn
@onready var animations_list: VBoxContainer = %AnimationsList
@onready var animations_scroll: ScrollContainer = %AnimationsScroll
@onready var add_animation_btn: Button = %AddAnimationBtn
@onready var clear_animations_btn: Button = %ClearAnimationsBtn
@onready var output_path_edit: LineEdit = %OutputPathEdit
@onready var browse_output_btn: Button = %BrowseOutputBtn
@onready var export_btn: Button = %ExportBtn
@onready var status_label: Label = %StatusLabel
@onready var blender_path_edit: LineEdit = %BlenderPathEdit
@onready var browse_blender_btn: Button = %BrowseBlenderBtn
@onready var help_button: Button = %HelpButton

var base_model_path: String = ""
var animation_paths: Array[String] = []
var blender_executable: String = DEFAULT_BLENDER_EXECUTABLE

var _export_thread: Thread = null

var base_file_dialog: EditorFileDialog
var anim_file_dialog: EditorFileDialog
var output_file_dialog: EditorFileDialog
var blender_file_dialog: EditorFileDialog


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	help_button.icon = get_theme_icon(&"NodeInfo", &"EditorIcons")
	_load_settings()
	_setup_file_dialogs()
	browse_base_model_btn.pressed.connect(_on_browse_base_model_pressed)
	clear_base_model_btn.pressed.connect(_on_clear_base_model_pressed)
	add_animation_btn.pressed.connect(_on_add_animation_pressed)
	clear_animations_btn.pressed.connect(_on_clear_animations_pressed)
	browse_output_btn.pressed.connect(_on_browse_output_pressed)
	export_btn.pressed.connect(_on_export_pressed)
	browse_blender_btn.pressed.connect(_on_browse_blender_pressed)
	output_path_edit.text_changed.connect(_on_output_path_changed)
	_update_ui()


func _setup_file_dialogs() -> void:
	base_file_dialog = EditorFileDialog.new()
	base_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	base_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	base_file_dialog.add_filter("*.fbx", "FBX Files")
	base_file_dialog.file_selected.connect(_on_base_model_selected)
	add_child(base_file_dialog)

	anim_file_dialog = EditorFileDialog.new()
	anim_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
	anim_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	anim_file_dialog.add_filter("*.fbx", "FBX Files")
	anim_file_dialog.files_selected.connect(_on_animations_selected)
	add_child(anim_file_dialog)

	output_file_dialog = EditorFileDialog.new()
	output_file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	output_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	output_file_dialog.add_filter("*.gltf", "GLTF Files")
	output_file_dialog.add_filter("*.glb", "GLB Files")
	output_file_dialog.file_selected.connect(_on_output_selected)
	add_child(output_file_dialog)

	blender_file_dialog = EditorFileDialog.new()
	blender_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	blender_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	blender_file_dialog.file_selected.connect(_on_blender_selected)
	add_child(blender_file_dialog)



func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.modulate = color


func _on_browse_base_model_pressed() -> void:
	base_file_dialog.popup_centered_ratio(0.7)


func _on_base_model_selected(path: String) -> void:
	base_model_path = path
	_update_ui()
	_save_settings()


func _on_clear_base_model_pressed() -> void:
	base_model_path = ""
	_update_ui()
	_save_settings()


func _on_add_animation_pressed() -> void:
	anim_file_dialog.popup_centered_ratio(0.7)


func _on_animations_selected(paths: PackedStringArray) -> void:
	for path: String in paths:
		if not path in animation_paths:
			animation_paths.append(path)
	_update_animation_list()
	_save_settings()


func _on_clear_animations_pressed() -> void:
	animation_paths.clear()
	_update_animation_list()
	_save_settings()


func _on_browse_output_pressed() -> void:
	output_file_dialog.popup_centered_ratio(0.7)


func _on_output_selected(path: String) -> void:
	output_path_edit.text = path
	_save_settings()


func _on_output_path_changed(_new_text: String) -> void:
	_save_settings()


func _on_browse_blender_pressed() -> void:
	blender_file_dialog.popup_centered_ratio(0.7)


func _on_blender_selected(path: String) -> void:
	if path.to_lower().ends_with(".fbx"):
		_set_status("Error: Please select Blender executable, not an FBX file", Color.RED)
		return
	var filename: String = path.get_file().to_lower()
	if not (filename == "blender" or filename.begins_with("blender")):
		_set_status("Warning: Selected file doesn't appear to be Blender", Color.YELLOW)
	blender_executable = path
	blender_path_edit.text = path
	_save_settings()


func _on_export_pressed() -> void:
	if not _validate_inputs():
		return
	_set_status("Exporting...", Color.YELLOW)
	export_btn.disabled = true

	var script_path: String = _get_script_path()
	var blender_exec: String = blender_executable if blender_executable != "" else "blender"

	if blender_executable != "" and not FileAccess.file_exists(blender_executable):
		_set_status("Error: Blender executable not found at: " + blender_executable, Color.RED)
		export_btn.disabled = false
		return

	if not FileAccess.file_exists(script_path):
		_set_status("Error: Python script not found at: " + script_path, Color.RED)
		export_btn.disabled = false
		return

	var args: PackedStringArray = [
		"--background",
		"--python", script_path,
		"--",
		"--model", base_model_path,
		"--animations",
	]
	for anim_path: String in animation_paths:
		args.append(anim_path)
	args.append("--output")
	args.append(output_path_edit.text)
	args.append("--json-output")

	print("Executing Blender command:")
	print("  Executable: ", blender_executable)
	print("  Script: ", script_path)
	print("  Base Model: ", base_model_path)
	print("  Animations: ", animation_paths)
	print("  Output: ", output_path_edit.text)
	print("  Arguments: ", args)

	_export_thread = Thread.new()
	_export_thread.start(_run_blender.bind(blender_exec, args, output_path_edit.text))


func _run_blender(blender_exec: String, args: PackedStringArray, output_path: String) -> void:
	var output: Array = []
	var exit_code: int = OS.execute(blender_exec, args, output, true, false)
	call_deferred("_on_blender_finished", exit_code, output, output_path)


func _on_blender_finished(exit_code: int, output: Array, output_path: String) -> void:
	if _export_thread:
		_export_thread.wait_to_finish()
		_export_thread = null
	export_btn.disabled = false

	print("Blender output:")
	for line: Variant in output:
		print(line)

	if exit_code != 0:
		_set_status("Blender failed! Exit code: " + str(exit_code), Color.RED)
		return

	var result: Dictionary = _parse_output(output)

	if result.has("success") and not result["success"]:
		_set_status("Python script error: " + result.get("error", "Unknown error"), Color.RED)
		return

	if not FileAccess.file_exists(output_path):
		_set_status("Export failed: output file not created", Color.RED)
		push_error("Output file not created at: " + output_path)
		return

	var file: FileAccess = FileAccess.open(output_path, FileAccess.READ)
	if not file:
		_set_status("File created but cannot read", Color.ORANGE)
		return

	var size: int = file.get_length()
	file.close()

	var suffix: String = ""
	if result.has("texture_conflicts"):
		var conflicts: Array = result["texture_conflicts"] as Array
		if not conflicts.is_empty():
			push_warning("Texture conflicts detected: " + str(conflicts))
			suffix = " (with texture conflicts)"

	_set_status("Export successful! (%d bytes)%s" % [size, suffix], Color.GREEN)


func _validate_inputs() -> bool:
	if base_model_path == "":
		_set_status("Error: No base model selected", Color.RED)
		return false
	if not FileAccess.file_exists(base_model_path):
		_set_status("Error: Base model file not found", Color.RED)
		return false
	if animation_paths.is_empty():
		_set_status("Error: No animations added", Color.RED)
		return false
	for anim_path: String in animation_paths:
		if not FileAccess.file_exists(anim_path):
			_set_status("Error: Animation file not found: " + anim_path, Color.RED)
			return false
	if output_path_edit.text == "":
		_set_status("Error: No output path specified", Color.RED)
		return false
	return true


# Returns the parsed JSON payload from the Python script, or {} if none was found.
func _parse_output(output: Array) -> Dictionary:
	var json_text: String = ""
	var in_json: bool = false

	for line: Variant in output:
		if not line is String:
			continue
		var s: String = (line as String).strip_edges()
		if s == "===JSON_START===":
			in_json = true
		elif s == "===JSON_END===":
			break
		elif in_json:
			json_text += (line as String) + "\n"

	if json_text == "":
		return {}

	var json: JSON = JSON.new()
	if json.parse(json_text) != OK:
		push_error("[animation_combiner] Failed to parse JSON output from Python script")
		return {}

	if not json.data is Dictionary:
		return {}

	var result: Dictionary = json.data as Dictionary
	if result.has("animations_added"):
		print("[INFO] Added ", (result["animations_added"] as Array).size(), " animations: ", result["animations_added"])

	return result


func _get_script_path() -> String:
	var addon_path: String = get_script().get_path().get_base_dir()
	return ProjectSettings.globalize_path(addon_path.path_join("main.py"))


func _update_ui() -> void:
	if base_model_path == "":
		base_model_path_edit.text = ""
		clear_base_model_btn.visible = false
	else:
		base_model_path_edit.text = base_model_path.get_file()
		clear_base_model_btn.visible = true
	blender_path_edit.text = blender_executable


func _update_animation_list() -> void:
	for child: Node in animations_list.get_children():
		child.queue_free()
	if animation_paths.is_empty():
		var hint: Label = Label.new()
		hint.text = "No animations added — click 'Add Animations'"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.modulate = Color(0.6, 0.6, 0.6, 1.0)
		animations_list.add_child(hint)
		return
	for i: int in range(animation_paths.size()):
		var hbox: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		label.text = animation_paths[i].get_file()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)
		var remove_btn: Button = Button.new()
		remove_btn.text = "Remove"
		remove_btn.pressed.connect(_on_remove_animation.bind(i))
		hbox.add_child(remove_btn)
		animations_list.add_child(hbox)


func _on_remove_animation(index: int) -> void:
	animation_paths.remove_at(index)
	_update_animation_list()
	_save_settings()


func _get_settings_path() -> String:
	return ProjectSettings.globalize_path("res://.godot/animation_combiner_settings.cfg")


func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("settings", "blender_executable", blender_executable)
	config.set_value("settings", "base_model_path", base_model_path)
	config.set_value("settings", "animation_paths", animation_paths)
	config.set_value("settings", "output_path", output_path_edit.text)
	config.save(_get_settings_path())


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(_get_settings_path()) != OK:
		return
	blender_executable = config.get_value("settings", "blender_executable", "")
	base_model_path = config.get_value("settings", "base_model_path", "")
	var saved_anims: Array = config.get_value("settings", "animation_paths", [])
	animation_paths.assign(saved_anims)
	output_path_edit.text = config.get_value("settings", "output_path", "")
	_update_animation_list()