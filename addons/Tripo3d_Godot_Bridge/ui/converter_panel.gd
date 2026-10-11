# converter_panel.gd
# UI panel for converting TripoModels to clean .res assets
@tool
extends VBoxContainer

signal convert_requested(source_dir: String, category: String, friendly_name: String)

const ROW_SEPARATION: int = 6
const FIELD_MIN_WIDTH: float = 120.0
const UUID_DISPLAY_LENGTH: int = 12
const DEFAULT_CATEGORY: String = "Uncategorized"

var _model_list_container: VBoxContainer
var _no_models_label: Label
var _status_label: Label
var _rows: Array[Dictionary] = []  # [{source_dir, name_edit, category_edit}]


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	add_theme_constant_override("separation", 8)

	# Header row with title and refresh button
	var header_row := HBoxContainer.new()
	var header := Label.new()
	header.text = TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.ASSET_CONVERTER)
	header.add_theme_font_size_override("font_size", 20)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header)

	var refresh_btn := Button.new()
	refresh_btn.text = TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.REFRESH)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	header_row.add_child(refresh_btn)
	add_child(header_row)

	# Scrollable model list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	_model_list_container = VBoxContainer.new()
	_model_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_model_list_container.add_theme_constant_override("separation", ROW_SEPARATION)
	scroll.add_child(_model_list_container)

	# No models label (shown when list is empty)
	_no_models_label = Label.new()
	_no_models_label.text = TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.NO_MODELS_FOUND)
	_no_models_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_models_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	_model_list_container.add_child(_no_models_label)

	# Status label
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_status_label)


func refresh_model_list(models: Array[Dictionary]) -> void:
	# Clear existing rows
	_rows.clear()
	for child in _model_list_container.get_children():
		child.queue_free()

	if models.is_empty():
		_no_models_label = Label.new()
		_no_models_label.text = TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.NO_MODELS_FOUND)
		_no_models_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_no_models_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		_model_list_container.add_child(_no_models_label)
		return

	for model in models:
		_add_model_row(model)


func set_status(text: String, is_error: bool = false) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = text
		_status_label.add_theme_color_override("font_color",
			Color(1.0, 0.45, 0.35) if is_error else Color(0.5, 1.0, 0.5))


func _add_model_row(model: Dictionary) -> void:
	var folder_name: String = model.get("folder_name", "")
	var source_dir: String = model.get("folder_path", "")

	var row_panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var tone := get_theme_color("font_color", "Label")
	style.bg_color = Color(tone.r, tone.g, tone.b, 0.05)
	style.border_color = Color(tone.r, tone.g, tone.b, 0.15)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	row_panel.add_theme_stylebox_override("panel", style)
	_model_list_container.add_child(row_panel)

	var row_vbox := VBoxContainer.new()
	row_vbox.add_theme_constant_override("separation", 4)
	row_panel.add_child(row_vbox)

	# Source label (truncated UUID)
	var source_label := Label.new()
	var display_name := folder_name
	if display_name.length() > UUID_DISPLAY_LENGTH:
		display_name = display_name.left(UUID_DISPLAY_LENGTH) + "..."
	source_label.text = TripoBridgeLocalization.get_text(
		TripoBridgeLocalization.Key.SOURCE) + " " + display_name
	source_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	source_label.tooltip_text = folder_name
	row_vbox.add_child(source_label)

	# Name field row
	var name_row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.FRIENDLY_NAME)
	name_label.custom_minimum_size = Vector2(50, 0)
	name_row.add_child(name_label)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "e.g. Rock01_SongDynasty"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size = Vector2(FIELD_MIN_WIDTH, 0)
	name_row.add_child(name_edit)
	row_vbox.add_child(name_row)

	# Category field row
	var cat_row := HBoxContainer.new()
	var cat_label := Label.new()
	cat_label.text = TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.CATEGORY)
	cat_label.custom_minimum_size = Vector2(50, 0)
	cat_row.add_child(cat_label)
	var cat_edit := LineEdit.new()
	cat_edit.text = DEFAULT_CATEGORY
	cat_edit.placeholder_text = "e.g. Rocks"
	cat_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_edit.custom_minimum_size = Vector2(FIELD_MIN_WIDTH, 0)
	cat_row.add_child(cat_edit)
	row_vbox.add_child(cat_row)

	# Convert button
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	var convert_btn := Button.new()
	convert_btn.text = TripoBridgeLocalization.get_text(TripoBridgeLocalization.Key.CONVERT)
	convert_btn.pressed.connect(_on_convert_pressed.bind(source_dir, name_edit, cat_edit))
	btn_row.add_child(convert_btn)
	row_vbox.add_child(btn_row)

	_rows.append({
		"source_dir": source_dir,
		"name_edit": name_edit,
		"category_edit": cat_edit,
	})


func _on_refresh_pressed() -> void:
	var models := TripoAssetConverter.scan_tripo_models()
	refresh_model_list(models)


func _on_convert_pressed(source_dir: String, name_edit: LineEdit, cat_edit: LineEdit) -> void:
	var friendly_name := name_edit.text.strip_edges()
	var category := cat_edit.text.strip_edges()

	if friendly_name.is_empty():
		set_status(TripoBridgeLocalization.get_text(
			TripoBridgeLocalization.Key.CONVERT_FAILED) + ": empty name", true)
		return

	if category.is_empty():
		category = DEFAULT_CATEGORY

	convert_requested.emit(source_dir, category, friendly_name)
