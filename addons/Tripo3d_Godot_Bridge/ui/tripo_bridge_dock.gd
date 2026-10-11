@tool
extends Control

const _ConverterPanel = preload("res://addons/Tripo3d_Godot_Bridge/ui/converter_panel.gd")

signal start_server_pressed
signal stop_server_pressed

const MAX_LOG_LINES: int = 100
const PROGRESS_UPDATE_THROTTLE: float = 0.5  # seconds
const SECTION_HEADER_FONT_SIZE: int = 20
const SECTION_BORDER_ALPHA: float = 0.22
const SECTION_BG_ALPHA: float = 0.05
const SECTION_SEPARATOR_ALPHA: float = 0.18
const STATUS_COLOR_CONNECTED := Color.GREEN
const STATUS_COLOR_LISTENING := Color(1.0, 0.75, 0.2, 1.0)
const STATUS_COLOR_DISCONNECTED := Color.RED
const STATUS_COLOR_ERROR := Color(1.0, 0.45, 0.35, 1.0)
const STATUS_KEY_MIN_WIDTH: float = 118.0
const PROGRESS_BAR_HEIGHT: float = 26.0

# UI references
var _start_stop_btn: Button
var _port_value_label: Label
var _conn_value_label: Label
var _file_value_label: Label
var _progress_bar: ProgressBar
var _log_edit: TextEdit
var _logo_rect: TextureRect
var _converter_panel = null
var _plugin_dir: String = ""

# State
var _is_connected: bool = false
var _server_status_override: String = ""
var _last_progress_time: float = 0.0
var _log_lines: Array = []

func _ready() -> void:
	_build_ui()
	_apply_logo()

func setup(plugin_dir: String) -> void:
	_plugin_dir = plugin_dir
	_apply_logo()

func _apply_logo() -> void:
	if _plugin_dir.is_empty() or not is_instance_valid(_logo_rect):
		return
	var logo_path := _plugin_dir + "/resources/tripo_logo.png"
	if ResourceLoader.exists(logo_path):
		_logo_rect.texture = load(logo_path)

func _build_ui() -> void:
	custom_minimum_size = Vector2(300, 500)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 8)
	add_child(root_vbox)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# --- Logo ---
	var logo_margin := MarginContainer.new()
	logo_margin.add_theme_constant_override("margin_top", 15)
	logo_margin.add_theme_constant_override("margin_left", 8)
	logo_margin.add_theme_constant_override("margin_right", 8)
	logo_margin.add_theme_constant_override("margin_bottom", 10)
	vbox.add_child(logo_margin)

	var logo_center := CenterContainer.new()
	logo_margin.add_child(logo_center)

	_logo_rect = TextureRect.new()
	_logo_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo_rect.custom_minimum_size = Vector2(220, 72)
	_logo_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_logo_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Texture is loaded later via setup(plugin_dir)
	logo_center.add_child(_logo_rect)

	# --- Server control ---
	var server_panel := PanelContainer.new()
	server_panel.add_theme_stylebox_override("panel", _make_section_style())
	vbox.add_child(server_panel)
	var server_vbox := VBoxContainer.new()
	server_vbox.add_theme_constant_override("separation", 4)
	server_panel.add_child(server_vbox)
	_start_stop_btn = Button.new()
	_start_stop_btn.text = TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.START_SERVER)
	_start_stop_btn.custom_minimum_size = Vector2(0, 30)
	_start_stop_btn.pressed.connect(_on_start_stop_pressed)
	server_vbox.add_child(_start_stop_btn)
	vbox.add_child(_make_section_separator())

	# --- Status section ---
	var status_panel := PanelContainer.new()
	status_panel.add_theme_stylebox_override("panel", _make_section_style())
	vbox.add_child(status_panel)
	var status_vbox := VBoxContainer.new()
	status_vbox.add_theme_constant_override("separation", 4)
	status_panel.add_child(status_vbox)

	status_vbox.add_child(_make_row(
		TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.PORT),
		str(TripoBridgeProtocolConstants.SERVER_PORT)))

	# Connection row (store label reference for color update)
	var conn_row := HBoxContainer.new()
	var conn_key := _make_key_label(TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.CONNECTION))
	conn_row.add_child(conn_key)
	_conn_value_label = Label.new()
	_conn_value_label.text = TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.DISCONNECTED)
	_conn_value_label.add_theme_color_override("font_color", STATUS_COLOR_DISCONNECTED)
	conn_row.add_child(_conn_value_label)
	status_vbox.add_child(conn_row)

	# File row
	var file_row := HBoxContainer.new()
	var file_key := _make_key_label(TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.FILE))
	file_row.add_child(file_key)
	_file_value_label = Label.new()
	_file_value_label.text = ""
	_file_value_label.clip_text = true
	_file_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	file_row.add_child(_file_value_label)
	status_vbox.add_child(file_row)

	var progress_header := Label.new()
	progress_header.text = TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.PROGRESS)
	progress_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_vbox.add_child(progress_header)
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.custom_minimum_size = Vector2(0, PROGRESS_BAR_HEIGHT)
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.show_percentage = true
	status_vbox.add_child(_progress_bar)
	vbox.add_child(_make_section_separator())

	# --- Log ---
	var log_panel := PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", _make_section_style())
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(log_panel)
	var log_vbox := VBoxContainer.new()
	log_vbox.add_theme_constant_override("separation", 4)
	log_panel.add_child(log_vbox)

	var log_header_row := HBoxContainer.new()
	var log_header := _make_section_header(TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.MESSAGE_LOG))
	log_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_header_row.add_child(log_header)
	var clear_btn := Button.new()
	clear_btn.text = TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.CLEAR)
	clear_btn.pressed.connect(_on_clear_pressed)
	log_header_row.add_child(clear_btn)
	log_vbox.add_child(log_header_row)

	_log_edit = TextEdit.new()
	_log_edit.editable = false
	_log_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_log_edit.custom_minimum_size = Vector2(0, 400)
	_log_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_vbox.add_child(_log_edit)

	# --- Asset Converter ---
	vbox.add_child(_make_section_separator())

	var converter_panel_container := PanelContainer.new()
	converter_panel_container.add_theme_stylebox_override("panel", _make_section_style())
	vbox.add_child(converter_panel_container)

	_converter_panel = _ConverterPanel.new()
	converter_panel_container.add_child(_converter_panel)

func _make_section_header(text: String, font_size: int = SECTION_HEADER_FONT_SIZE) -> Label:
	var header := Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", font_size)
	return header

func _make_section_style() -> StyleBoxFlat:
	var tone := get_theme_color("font_color", "Label")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tone.r, tone.g, tone.b, SECTION_BG_ALPHA)
	style.border_color = Color(tone.r, tone.g, tone.b, SECTION_BORDER_ALPHA)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	return style

func _make_section_separator() -> ColorRect:
	var tone := get_theme_color("font_color", "Label")
	var separator := ColorRect.new()
	separator.custom_minimum_size = Vector2(0, 1)
	separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	separator.color = Color(tone.r, tone.g, tone.b, SECTION_SEPARATOR_ALPHA)
	return separator

func _make_row(key_text: String, value_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var k := _make_key_label(key_text)
	row.add_child(k)
	var v := Label.new()
	v.text = value_text
	row.add_child(v)
	return row

func _make_key_label(key_text: String) -> Label:
	var key := Label.new()
	key.text = _format_key_text(key_text)
	key.custom_minimum_size = Vector2(STATUS_KEY_MIN_WIDTH, 0)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return key

func _format_key_text(key_text: String) -> String:
	var text := key_text.strip_edges()
	while text.ends_with(":") or text.ends_with("："):
		text = text.left(text.length() - 1).strip_edges()
	return text + ":"

# --- Public update methods ---

func update_server_state(running: bool) -> void:
	_server_running = running
	if running:
		_server_status_override = ""
	if not is_instance_valid(_start_stop_btn):
		return
	if running:
		_start_stop_btn.text = TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.STOP_SERVER)
		_start_stop_btn.add_theme_color_override("font_color", Color.WHITE)
		_start_stop_btn.modulate = Color(0.7, 0.7, 0.7, 1.0)
	else:
		_start_stop_btn.text = TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.START_SERVER)
		_start_stop_btn.modulate = Color(0.5, 1.0, 0.5, 1.0)
	_refresh_connection_status()

func update_connection(connected: bool) -> void:
	_is_connected = connected
	if connected:
		_server_status_override = ""
	_refresh_connection_status()

func show_server_error(text: String) -> void:
	_server_status_override = text
	_refresh_connection_status()

func _refresh_connection_status() -> void:
	if not is_instance_valid(_conn_value_label):
		return
	if _is_connected:
		_conn_value_label.text = TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.CONNECTED)
		_conn_value_label.add_theme_color_override("font_color", STATUS_COLOR_CONNECTED)
	elif not _server_status_override.is_empty():
		_conn_value_label.text = _server_status_override
		_conn_value_label.add_theme_color_override("font_color", STATUS_COLOR_ERROR)
	elif _server_running:
		_conn_value_label.text = TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.LISTENING)
		_conn_value_label.add_theme_color_override("font_color", STATUS_COLOR_LISTENING)
	else:
		_conn_value_label.text = TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.DISCONNECTED)
		_conn_value_label.add_theme_color_override("font_color", STATUS_COLOR_DISCONNECTED)
	if is_instance_valid(_progress_bar) and not _is_connected:
		_progress_bar.value = 0.0
	if is_instance_valid(_file_value_label) and not _is_connected:
		_file_value_label.text = ""

func update_progress(progress: float) -> void:
	if not is_instance_valid(_progress_bar):
		return
	var clamped_progress := clampf(progress, _progress_bar.min_value, _progress_bar.max_value)
	var is_terminal_progress := is_equal_approx(clamped_progress, _progress_bar.min_value) \
		or is_equal_approx(clamped_progress, _progress_bar.max_value)
	var now := Time.get_ticks_msec() / 1000.0
	if not is_terminal_progress and now - _last_progress_time < PROGRESS_UPDATE_THROTTLE:
		return
	_last_progress_time = now
	_progress_bar.value = clamped_progress

func update_file(file_name: String) -> void:
	if is_instance_valid(_file_value_label):
		_file_value_label.text = file_name.get_file().get_basename()

func add_log(message: String) -> void:
	_log_lines.append(message)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	if is_instance_valid(_log_edit):
		_log_edit.text = "\n".join(_log_lines)
		# Scroll to bottom
		_log_edit.scroll_vertical = _log_edit.get_line_count()

# --- Button callbacks ---

func _on_start_stop_pressed() -> void:
	if _is_server_running():
		stop_server_pressed.emit()
	else:
		start_server_pressed.emit()

func _on_clear_pressed() -> void:
	_log_lines.clear()
	if is_instance_valid(_log_edit):
		_log_edit.text = ""

# Set by plugin after each start/stop
var _server_running: bool = false

func set_server_running(v: bool) -> void:
	update_server_state(v)

func _is_server_running() -> bool:
	return _server_running

func get_converter_panel():
	return _converter_panel
