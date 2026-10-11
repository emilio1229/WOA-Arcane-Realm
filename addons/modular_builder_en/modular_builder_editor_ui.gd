@tool
extends EditorPlugin

const PIECE_SCRIPT = preload("res://addons/modular_builder_en/modular_piece.gd")
const DETAIL_SCRIPT = preload("res://addons/modular_builder_en/modular_building_detail.gd")
const MESH_BAKER = preload("res://addons/modular_builder_en/modular_mesh_baker.gd")
const TOOL_NONE := ""
const TOOL_FOUNDATION := "foundation"
const TOOL_FOUNDATION_SQUARE := "foundation_square"
const TOOL_FOUNDATION_TRIANGLE := "foundation_triangle"
const TOOL_WALL := "wall"
const TOOL_GABLE_WALL := "gable_wall"
const TOOL_GABLE_WALL_RIGHT := "gable_wall_right"
const TOOL_FLOOR_SQUARE := "floor_square"
const TOOL_FLOOR_TRIANGLE := "floor_triangle"
const TOOL_ROOF_GABLE := "roof_gable"
const TOOL_ROOF_SHED := "roof_shed"
const TOOL_ROOF_PYRAMID := "roof_pyramid"
const TOOL_STAIRS := "stairs"
const TOOL_FENCE := "fence"
const TOOL_PARAPET := "parapet"
const TOOL_MERGE_VERTICES := "merge_vertices"
const TOOL_CREATE_VERTEX := "create_vertex"
const TOOL_MOVE_VERTEX := "move_vertex"
const TOOL_REMOVE_VERTEX := "remove_vertex"
const MERGED_VERTEX_GROUPS_META := &"modular_builder_merged_vertex_groups"
const CUSTOM_VERTICES_META := &"modular_builder_custom_vertices"
const TOOL_WINDOW := "detail_window"
const TOOL_DOOR := "detail_door"
const TOOL_HATCH := "detail_hatch"
const TOOL_PILLAR := "detail_pillar"
const EXPORT_NEW_SCENE := 0
const EXPORT_SCENE_COPY := 1
const METERS_TO_GODOT_UNITS := 1.0
const DOOR_DEFAULT_SCALE := 0.8
const DOOR_DEFAULT_WIDTH_METERS := 0.87 * DOOR_DEFAULT_SCALE
const DOOR_DEFAULT_HEIGHT_METERS := 2.15 * DOOR_DEFAULT_SCALE
const MARKER_RADIUS := 8.0
const MARKER_HIT_RADIUS := 18.0

var dock: VBoxContainer
var _creation_row: HFlowContainer
var _export_row: HFlowContainer
var _tool_row: HFlowContainer
var _vertex_edit_row: HFlowContainer
var _marker_scope_check: CheckBox
var _simplify_vertices_check: CheckBox
var _rise_options_row: HFlowContainer
var _linear_options_row: HFlowContainer
var _stair_count_label: Label
var _stair_width_label: Label
var _fence_divisions_label: Label
var _detail_options_row: HFlowContainer
var _foundation_type_selected := ModularBuilderPiece.PieceType.FOUNDATION_SQUARE
var size_spin: SpinBox
var rise_spin: SpinBox
var stair_count_spin: SpinBox
var stair_width_spin: SpinBox
var fence_divisions_spin: SpinBox
var fence_height_spin: SpinBox
var _fence_height_label: Label
var _rise_label: Label
var _gable_centralize_check: CheckBox
var _gable_centralize_default := false
var detail_width_spin: SpinBox
var detail_height_spin: SpinBox
var detail_height_offset_spin: SpinBox
var _detail_height_offset_label: Label
var _detail_width_label: Label
var _detail_height_label: Label
var detail_mode_option: OptionButton
var detail_style_option: OptionButton
var status_label: Label
var active_tool := TOOL_NONE
var pending_points: Array[Vector3] = []
var _redirecting_selection := false
var _marker_container: Node3D
var _marker_root: ModularBuilderPiece
var _marker_point_nodes: Array[Label3D] = []
var _side_button_nodes: Array[Label3D] = []
var _side_material: StandardMaterial3D
var _tool_button_group: ButtonGroup
var _tool_buttons: Dictionary = {}
var _pillar_centralize_check: CheckBox
var _pillar_centralize_default := false
var _active_button_key := ""
var _last_created_piece: ModularBuilderPiece
var _detail_preview: ModularBuilderDetail
var _preview_material: StandardMaterial3D
var _preview_camera: Camera3D
var _preview_screen_position := Vector2.ZERO
var _save_module_dialog: FileDialog
var _load_module_dialog: FileDialog
var _export_scene_dialog: FileDialog
var _export_mode_option: OptionButton
var _pending_export_mesh: ArrayMesh
var _pending_export_name := "BakedBuilding"
var _pending_export_basis := Basis.IDENTITY
var _selected_window_style := ModularBuilderDetail.WindowStyle.SINGLE_PANE
var _selected_door_style := ModularBuilderDetail.DoorStyle.FLAT
var _editor_sync_elapsed := 0.0

func _ready() -> void:
	set_process(true)
	_side_material = StandardMaterial3D.new()
	_side_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_side_material.albedo_color = Color(0.18, 0.95, 0.52)
	_side_material.no_depth_test = true
	_side_material.cull_mode = BaseMaterial3D.CULL_DISABLED

func _process(delta: float) -> void:
	_editor_sync_elapsed += delta
	if _editor_sync_elapsed < 1.0 / 15.0:
		return
	_editor_sync_elapsed = 0.0
	call("_sync_vertex_markers")
	_sync_pillar_centralize_control()
	_sync_gable_centralize_control()

func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.name = "Modular Builder"
	dock.custom_minimum_size = Vector2(0, 110)
	_creation_row = HFlowContainer.new()
	dock.add_child(_creation_row)
	_creation_row.add_child(_label("Size:"))
	size_spin = SpinBox.new()
	size_spin.min_value = 0.5
	size_spin.max_value = 8.0
	size_spin.step = 0.001
	size_spin.value = 2.0
	size_spin.suffix = " m"
	size_spin.custom_minimum_size = Vector2(100, 0)
	_creation_row.add_child(size_spin)
	var create_button := _make_icon_button("res://addons/modular_builder_en/icons/add_building.svg", "Add ModularBuilderPiece", Color(0.22, 0.30, 0.38))
	create_button.pressed.connect(Callable(self, "_add_piece"))
	_creation_row.add_child(create_button)
	var rotate_button := _make_icon_button("res://addons/modular_builder_en/icons/rotate.svg", "Rotate selected piece 90°", Color(0.22, 0.30, 0.38))
	rotate_button.pressed.connect(Callable(self, "_rotate_selected_piece"))
	_creation_row.add_child(rotate_button)
	var collision_button := _make_icon_button("res://addons/modular_builder_en/icons/collision.svg", "Add general collision to selected structure", Color(0.22, 0.30, 0.38))
	collision_button.pressed.connect(Callable(self, "_add_general_collision"))
	_creation_row.add_child(collision_button)
	var save_module_button := _make_icon_button("res://addons/modular_builder_en/icons/save_module.svg", "Save selected structure as a .tscn module", Color(0.22, 0.30, 0.38))
	save_module_button.pressed.connect(Callable(self, "_show_save_module_dialog"))
	_creation_row.add_child(save_module_button)
	var load_module_button := _make_icon_button("res://addons/modular_builder_en/icons/load_module.svg", "Insert saved module into the scene", Color(0.22, 0.30, 0.38))
	load_module_button.pressed.connect(Callable(self, "_show_load_module_dialog"))
	_creation_row.add_child(load_module_button)
	_export_row = HFlowContainer.new()
	dock.add_child(_export_row)
	_export_row.add_child(_label("Export structure as mesh:") )
	_export_mode_option = OptionButton.new()
	_export_mode_option.add_item("New scene", EXPORT_NEW_SCENE)
	_export_mode_option.add_item("Copy in this scene", EXPORT_SCENE_COPY)
	_export_mode_option.tooltip_text = "Choose whether to save the combined mesh as a new scene or add a copy to the current scene."
	_export_row.add_child(_export_mode_option)
	var export_button := Button.new()
	export_button.text = "Export"
	export_button.tooltip_text = "Generate one static mesh with materials and UVs from the selected structure."
	export_button.pressed.connect(Callable(self, "_on_export_pressed"))
	_export_row.add_child(export_button)
	_tool_row = HFlowContainer.new()
	dock.add_child(_tool_row)
	_tool_button_group = ButtonGroup.new()
	_tool_button_group.allow_unpress = true
	_add_tool_button("res://addons/modular_builder_en/icons/foundation_square.svg", "Square foundation", TOOL_FOUNDATION_SQUARE, Color(0.08, 0.48, 0.22))
	_add_tool_button("res://addons/modular_builder_en/icons/foundation_triangle.svg", "Triangular foundation", TOOL_FOUNDATION_TRIANGLE, Color(0.08, 0.48, 0.22))
	_add_tool_button("res://addons/modular_builder_en/icons/wall.svg", "Wall", TOOL_WALL, Color(0.65, 0.12, 0.12))
	_add_tool_button("res://addons/modular_builder_en/icons/gable_wall.svg", "Gable wall", TOOL_GABLE_WALL, Color(0.65, 0.12, 0.12))
	_add_tool_button("res://addons/modular_builder_en/icons/gable_wall_right.svg", "Right triangular gable wall", TOOL_GABLE_WALL_RIGHT, Color(0.65, 0.12, 0.12))
	_add_tool_button("res://addons/modular_builder_en/icons/floor_square.svg", "Square floor", TOOL_FLOOR_SQUARE, Color(0.68, 0.48, 0.06))
	_add_tool_button("res://addons/modular_builder_en/icons/floor_triangle.svg", "Triangular floor", TOOL_FLOOR_TRIANGLE, Color(0.68, 0.48, 0.06))
	_add_tool_button("res://addons/modular_builder_en/icons/roof_gable.svg", "Gable roof", TOOL_ROOF_GABLE, Color(0.10, 0.38, 0.62))
	_add_tool_button("res://addons/modular_builder_en/icons/roof_shed.svg", "Shed roof", TOOL_ROOF_SHED, Color(0.10, 0.38, 0.62))
	_add_tool_button("res://addons/modular_builder_en/icons/roof_pyramid.svg", "Pyramid roof", TOOL_ROOF_PYRAMID, Color(0.10, 0.38, 0.62))
	_add_tool_button("res://addons/modular_builder_en/icons/stairs.svg", "Stairs", TOOL_STAIRS, Color(0.10, 0.38, 0.62))
	_add_tool_button("res://addons/modular_builder_en/icons/fence.svg", "Decorative fence", TOOL_FENCE, Color(0.88, 0.22, 0.55))
	_add_tool_button("res://addons/modular_builder_en/icons/parapet.svg", "Parapet: single rail and posts", TOOL_PARAPET, Color(0.88, 0.22, 0.55))
	_add_tool_button("res://addons/modular_builder_en/icons/window.svg", "Detail: window", TOOL_WINDOW, Color(0.88, 0.22, 0.55))
	_add_tool_button("res://addons/modular_builder_en/icons/door.svg", "Detail: door", TOOL_DOOR, Color(0.88, 0.22, 0.55))
	_add_tool_button("res://addons/modular_builder_en/icons/hatch.svg", "Detail: hatch", TOOL_HATCH, Color(0.88, 0.22, 0.55))
	_add_tool_button("res://addons/modular_builder_en/icons/pillar.svg", "Plain pillar: two vertices or Alt+click for a vertical pillar", TOOL_PILLAR, Color(0.88, 0.22, 0.55))
	var cancel_button := _make_icon_button("res://addons/modular_builder_en/icons/cancel.svg", "Deactivate tool", Color(0.34, 0.20, 0.20))
	cancel_button.pressed.connect(Callable(self, "_set_tool").bind(TOOL_NONE))
	_tool_row.add_child(cancel_button)
	_vertex_edit_row = HFlowContainer.new()
	dock.add_child(_vertex_edit_row)
	_vertex_edit_row.add_child(_label("Vertices:"))
	_add_tool_button("res://addons/modular_builder_en/icons/merge_vertices.svg", "Merge vertices to reduce markers", TOOL_MERGE_VERTICES, Color(0.38, 0.32, 0.52), _vertex_edit_row)
	_add_tool_button("res://addons/modular_builder_en/icons/create_vertex.svg", "Create a connection vertex on the clicked surface", TOOL_CREATE_VERTEX, Color(0.38, 0.32, 0.52), _vertex_edit_row)
	_add_tool_button("res://addons/modular_builder_en/icons/move_vertex.svg", "Move a manual connection vertex", TOOL_MOVE_VERTEX, Color(0.38, 0.32, 0.52), _vertex_edit_row)
	_add_tool_button("res://addons/modular_builder_en/icons/remove_vertex.svg", "Remove a manual connection vertex", TOOL_REMOVE_VERTEX, Color(0.38, 0.32, 0.52), _vertex_edit_row)
	var marker_options_row := HFlowContainer.new()
	dock.add_child(marker_options_row)
	_marker_scope_check = CheckBox.new()
	_marker_scope_check.text = "Only show points on selected pieces"
	_marker_scope_check.tooltip_text = "Limit markers to pieces selected in the Scene tree. Selecting the structure container shows all its points."
	_marker_scope_check.toggled.connect(Callable(self, "_on_marker_scope_toggled"))
	marker_options_row.add_child(_marker_scope_check)
	_simplify_vertices_check = CheckBox.new()
	_simplify_vertices_check.text = "Simplify vertices"
	_simplify_vertices_check.tooltip_text = "Merge front and back points at the middle of walls and pillars; floors and foundations show their top outline. Vertex editing tools show the exact points."
	_simplify_vertices_check.toggled.connect(Callable(self, "_on_simplify_vertices_toggled"))
	marker_options_row.add_child(_simplify_vertices_check)
	_rise_options_row = HFlowContainer.new()
	dock.add_child(_rise_options_row)
	_rise_label = _label("Peak rise:")
	_rise_options_row.add_child(_rise_label)
	rise_spin = _detail_spin(1.0, 0.1, 8.0, 0.001)
	_rise_options_row.add_child(rise_spin)
	_linear_options_row = HFlowContainer.new()
	dock.add_child(_linear_options_row)
	_stair_count_label = _label("Steps:")
	_linear_options_row.add_child(_stair_count_label)
	stair_count_spin = SpinBox.new()
	stair_count_spin.min_value = 1
	stair_count_spin.max_value = 100
	stair_count_spin.step = 1
	stair_count_spin.value = 10
	stair_count_spin.custom_minimum_size = Vector2(72, 0)
	_linear_options_row.add_child(stair_count_spin)
	_stair_width_label = _label("Width:")
	_linear_options_row.add_child(_stair_width_label)
	stair_width_spin = _detail_spin(1.0, 0.01, 8.0, 0.001)
	_linear_options_row.add_child(stair_width_spin)
	_fence_divisions_label = _label("Intermediate posts:")
	_linear_options_row.add_child(_fence_divisions_label)
	fence_divisions_spin = SpinBox.new()
	fence_divisions_spin.min_value = 0
	fence_divisions_spin.max_value = 100
	fence_divisions_spin.step = 1
	fence_divisions_spin.value = 1
	fence_divisions_spin.custom_minimum_size = Vector2(72, 0)
	_linear_options_row.add_child(fence_divisions_spin)
	_fence_height_label = _label("Height:")
	_linear_options_row.add_child(_fence_height_label)
	fence_height_spin = _detail_spin(0.7, 0.1, 8.0, 0.001)
	_linear_options_row.add_child(fence_height_spin)
	_linear_options_row.visible = false
	_gable_centralize_check = CheckBox.new()
	_gable_centralize_check.text = "Center"
	_gable_centralize_check.tooltip_text = "Align the gable with the center of the supporting wall thickness."
	_gable_centralize_check.visible = false
	_gable_centralize_check.toggled.connect(_on_gable_centralize_toggled)
	_rise_options_row.add_child(_gable_centralize_check)
	_rise_options_row.visible = false
	_detail_options_row = HFlowContainer.new()
	dock.add_child(_detail_options_row)
	_detail_width_label = _label("Width:")
	_detail_options_row.add_child(_detail_width_label)
	detail_width_spin = _detail_spin(1.0, 0.01, 5.0, 0.001)
	_detail_options_row.add_child(detail_width_spin)
	_detail_height_label = _label("Height:")
	_detail_options_row.add_child(_detail_height_label)
	detail_height_spin = _detail_spin(1.0, 0.2, 5.0, 0.001)
	_detail_options_row.add_child(detail_height_spin)
	_pillar_centralize_check = CheckBox.new()
	_pillar_centralize_check.text = "Center"
	_pillar_centralize_check.tooltip_text = "Align the pillar with the nearest axis of the first vertex’s piece while keeping it centered between the points."
	_pillar_centralize_check.visible = false
	_pillar_centralize_check.toggled.connect(_on_pillar_centralize_toggled)
	_detail_options_row.add_child(_pillar_centralize_check)
	_detail_height_offset_label = _label("Starting height:")
	_detail_options_row.add_child(_detail_height_offset_label)
	detail_height_offset_spin = _detail_spin(0.0, -2.0, 2.0, 0.001)
	detail_height_offset_spin.suffix = " m"
	_detail_options_row.add_child(detail_height_offset_spin)
	detail_mode_option = OptionButton.new()
	detail_mode_option.add_item("Opening", ModularBuilderDetail.DetailMode.OPENING)
	detail_mode_option.add_item("Opening + object", ModularBuilderDetail.DetailMode.SEPARATE_OBJECT)
	detail_mode_option.select(0)
	detail_mode_option.tooltip_text = "Choose an opening alone or an opening with a separately textured object."
	_detail_options_row.add_child(detail_mode_option)
	detail_style_option = OptionButton.new()
	detail_style_option.tooltip_text = "Window or door style."
	detail_style_option.item_selected.connect(_on_detail_style_selected)
	_detail_options_row.add_child(detail_style_option)
	detail_width_spin.value_changed.connect(Callable(self, "_refresh_detail_preview"))
	detail_height_spin.value_changed.connect(Callable(self, "_refresh_detail_preview"))
	detail_height_offset_spin.value_changed.connect(Callable(self, "_refresh_detail_preview"))
	detail_mode_option.item_selected.connect(_on_detail_mode_selected)
	_detail_options_row.visible = false
	_preview_material = StandardMaterial3D.new()
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.albedo_color = Color(1.0, 0.35, 0.72, 0.48)
	_save_module_dialog = FileDialog.new()
	_save_module_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_module_dialog.access = FileDialog.ACCESS_RESOURCES
	_save_module_dialog.add_filter("*.tscn", "Godot Scene")
	_save_module_dialog.file_selected.connect(Callable(self, "_save_module_to_path"))
	add_child(_save_module_dialog)
	_load_module_dialog = FileDialog.new()
	_load_module_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_load_module_dialog.access = FileDialog.ACCESS_RESOURCES
	_load_module_dialog.add_filter("*.tscn", "Godot Scene")
	_load_module_dialog.file_selected.connect(Callable(self, "_load_module_from_path"))
	add_child(_load_module_dialog)
	_export_scene_dialog = FileDialog.new()
	_export_scene_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_scene_dialog.access = FileDialog.ACCESS_RESOURCES
	_export_scene_dialog.add_filter("*.tscn", "Godot Scene")
	_export_scene_dialog.file_selected.connect(Callable(self, "_export_baked_scene_to_path"))
	add_child(_export_scene_dialog)
	status_label = _label("Select a tool to show the vertices.")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(status_label)
	add_control_to_bottom_panel(dock, "Modular Builder")
	set_input_event_forwarding_always_enabled()
	get_editor_interface().get_selection().selection_changed.connect(Callable(self, "_on_editor_selection_changed"))
	var inspector := get_editor_interface().get_inspector()
	if not inspector.property_edited.is_connected(_on_inspector_property_edited):
		inspector.property_edited.connect(_on_inspector_property_edited)

func _exit_tree() -> void:
	set_process(false)
	var editor_selection := get_editor_interface().get_selection()
	if editor_selection.selection_changed.is_connected(Callable(self, "_on_editor_selection_changed")):
		editor_selection.selection_changed.disconnect(Callable(self, "_on_editor_selection_changed"))
	var inspector := get_editor_interface().get_inspector()
	if inspector.property_edited.is_connected(_on_inspector_property_edited):
		inspector.property_edited.disconnect(_on_inspector_property_edited)
	if dock:
		remove_control_from_bottom_panel(dock)
		dock.queue_free()
	call("_clear_marker_container")
	call("_clear_detail_preview")
	update_overlays()

func _handles(object: Object) -> bool:
	return object is ModularBuilderPiece

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

func _detail_spin(value: float, minimum: float, maximum: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = value
	spin.suffix = " m"
	spin.custom_minimum_size = Vector2(84, 0)
	return spin

func _make_icon_button(icon_path: String, tooltip: String, color: Color) -> Button:
	var button := Button.new()
	button.icon = load(icon_path) as Texture2D
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(48, 48)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 30)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(4)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.02, 0.02, 0.02)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.16)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.lightened(0.28)
	pressed.border_width_bottom = 3
	button.add_theme_stylebox_override("pressed", pressed)
	return button

func _add_tool_button(icon_path: String, tooltip: String, tool: String, color: Color, target_row: Container = null) -> void:
	var button := _make_icon_button(icon_path, tooltip, color)
	button.toggle_mode = true
	button.button_group = _tool_button_group
	button.toggled.connect(_on_tool_button_toggled.bind(tool))
	(_tool_row if target_row == null else target_row).add_child(button)
	_tool_buttons[tool] = button

func _on_tool_button_toggled(pressed: bool, tool: String) -> void:
	var is_foundation := tool == TOOL_FOUNDATION_SQUARE or tool == TOOL_FOUNDATION_TRIANGLE
	if pressed:
		_active_button_key = tool
		if is_foundation:
			_foundation_type_selected = ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE if tool == TOOL_FOUNDATION_TRIANGLE else ModularBuilderPiece.PieceType.FOUNDATION_SQUARE
			call("_set_tool", TOOL_FOUNDATION)
		else:
			call("_set_tool", tool)
			_update_detail_options(tool)
	else:
		call_deferred("_finish_tool_button_toggle_off", tool)

func _finish_tool_button_toggle_off(tool: String) -> void:
	var button := _tool_buttons.get(tool) as Button
	if button != null and not button.button_pressed and _active_button_key == tool:
		call("_set_tool", TOOL_NONE)

func _update_detail_options(tool: String) -> void:
	var is_detail := _is_detail_tool(tool)
	var is_fence := tool == TOOL_FENCE or tool == TOOL_PARAPET
	_detail_options_row.visible = is_detail
	detail_width_spin.visible = is_detail and not is_fence
	_detail_width_label.visible = is_detail and not is_fence
	detail_height_spin.visible = is_detail and not is_fence
	_detail_height_label.visible = is_detail and not is_fence
	detail_height_offset_spin.visible = tool != TOOL_HATCH and tool != TOOL_PILLAR and not is_fence
	_detail_height_offset_label.visible = detail_height_offset_spin.visible
	detail_mode_option.visible = tool != TOOL_PILLAR and not is_fence
	_detail_width_label.text = "Side:" if tool == TOOL_PILLAR else "Width:"
	_detail_height_label.text = "Length:" if tool == TOOL_PILLAR else "Height:"
	_linear_options_row.visible = tool == TOOL_STAIRS or is_fence
	_stair_count_label.visible = tool == TOOL_STAIRS
	stair_count_spin.visible = tool == TOOL_STAIRS
	_stair_width_label.visible = tool == TOOL_STAIRS
	stair_width_spin.visible = tool == TOOL_STAIRS
	_fence_divisions_label.visible = is_fence
	fence_divisions_spin.visible = is_fence
	_fence_height_label.visible = is_fence
	fence_height_spin.visible = is_fence
	if not is_detail:
		return
	var width := 1.0
	var height := 1.0
	var bottom_offset := 0.5
	if tool == TOOL_PILLAR:
		width = 0.2
		height = 2.0
		bottom_offset = 0.0
	elif tool == TOOL_DOOR:
		width = DOOR_DEFAULT_WIDTH_METERS
		height = DOOR_DEFAULT_HEIGHT_METERS
		bottom_offset = 0.0
	elif tool == TOOL_HATCH:
		bottom_offset = 0.0
	detail_width_spin.set_value_no_signal(width)
	detail_height_spin.set_value_no_signal(height)
	detail_height_offset_spin.set_value_no_signal(bottom_offset)
	detail_style_option.clear()
	detail_style_option.visible = tool == TOOL_WINDOW or tool == TOOL_DOOR
	if tool == TOOL_WINDOW:
		detail_style_option.add_item("Single pane", ModularBuilderDetail.WindowStyle.SINGLE_PANE)
		detail_style_option.add_item("Cross pane", ModularBuilderDetail.WindowStyle.CROSS_PANE)
		detail_style_option.select(_selected_window_style)
	elif tool == TOOL_DOOR:
		detail_style_option.add_item("Flat", ModularBuilderDetail.DoorStyle.FLAT)
		detail_style_option.add_item("Paneled", ModularBuilderDetail.DoorStyle.PANELED)
		detail_style_option.select(_selected_door_style)
	call("_refresh_detail_preview")

func _on_detail_style_selected(index: int) -> void:
	if active_tool == TOOL_WINDOW:
		_selected_window_style = index
		if is_instance_valid(_detail_preview):
			_detail_preview.window_style = index
	elif active_tool == TOOL_DOOR:
		_selected_door_style = index
		if is_instance_valid(_detail_preview):
			_detail_preview.door_style = index
	call("_refresh_detail_preview")

func _on_detail_mode_selected(_index: int) -> void:
	call("_refresh_detail_preview")

func _on_pillar_centralize_toggled(enabled: bool) -> void:
	_pillar_centralize_default = enabled
	var selected_pillar := _get_selected_pillar_detail()
	if selected_pillar != null:
		selected_pillar.center_align = enabled
	if is_instance_valid(_detail_preview) and _detail_preview.detail_type == ModularBuilderDetail.DetailType.PILLAR:
		_detail_preview.center_align = enabled
	call("_refresh_detail_preview")

func _on_gable_centralize_toggled(enabled: bool) -> void:
	_gable_centralize_default = enabled
	var selected := _get_selected_gable_wall()
	if selected != null:
		selected.center_align = enabled

func _sync_gable_centralize_control() -> void:
	if _gable_centralize_check == null:
		return
	var selected := _get_selected_gable_wall()
	var show_option := active_tool == TOOL_WALL or active_tool == TOOL_GABLE_WALL or active_tool == TOOL_GABLE_WALL_RIGHT or selected != null
	var show_rise := active_tool == TOOL_GABLE_WALL or active_tool == TOOL_GABLE_WALL_RIGHT or active_tool == TOOL_ROOF_GABLE or active_tool == TOOL_ROOF_PYRAMID
	_rise_options_row.visible = show_rise or selected != null
	_rise_label.visible = show_rise
	rise_spin.visible = show_rise
	_gable_centralize_check.visible = show_option
	_gable_centralize_check.text = "Center walls" if active_tool == TOOL_WALL or (selected != null and selected.piece_type == ModularBuilderPiece.PieceType.WALL) else "Center"
	_gable_centralize_check.tooltip_text = "Align wall endpoints with the centerlines of supporting walls." if active_tool == TOOL_WALL or (selected != null and selected.piece_type == ModularBuilderPiece.PieceType.WALL) else "Align the gable with the center of the supporting wall thickness."
	if selected != null:
		_gable_centralize_default = selected.center_align
		_gable_centralize_check.set_pressed_no_signal(selected.center_align)
	else:
		_gable_centralize_check.set_pressed_no_signal(_gable_centralize_default)

func _get_selected_gable_wall() -> ModularBuilderPiece:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.size() == 1 and selected[0] is ModularBuilderPiece and (selected[0].piece_type == ModularBuilderPiece.PieceType.WALL or selected[0].piece_type == ModularBuilderPiece.PieceType.GABLE_WALL or selected[0].piece_type == ModularBuilderPiece.PieceType.GABLE_WALL_RIGHT):
		return selected[0] as ModularBuilderPiece
	return null

func _sync_pillar_centralize_control() -> void:
	if _pillar_centralize_check == null:
		return
	var selected_pillar := _get_selected_pillar_detail()
	var show_pillar_options := active_tool == TOOL_PILLAR or selected_pillar != null
	_detail_options_row.visible = _is_detail_tool(active_tool) or show_pillar_options
	_pillar_centralize_check.visible = show_pillar_options
	if selected_pillar != null and active_tool != TOOL_PILLAR and not _is_detail_tool(active_tool):
		_detail_width_label.visible = false
		detail_width_spin.visible = false
		_detail_height_label.visible = false
		detail_height_spin.visible = false
		_detail_height_offset_label.visible = false
		detail_height_offset_spin.visible = false
		detail_mode_option.visible = false
		detail_style_option.visible = false
	elif active_tool == TOOL_PILLAR:
		_detail_width_label.visible = true
		detail_width_spin.visible = true
		_detail_height_label.visible = true
		detail_height_spin.visible = true
	if selected_pillar != null:
		_pillar_centralize_default = selected_pillar.center_align
		_pillar_centralize_check.set_pressed_no_signal(selected_pillar.center_align)
	else:
		_pillar_centralize_check.set_pressed_no_signal(_pillar_centralize_default)

func _get_selected_pillar_detail() -> ModularBuilderDetail:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.size() != 1 or not selected[0] is ModularBuilderDetail:
		return null
	var detail := selected[0] as ModularBuilderDetail
	return detail if detail.detail_type == ModularBuilderDetail.DetailType.PILLAR else null

func _on_inspector_property_edited(property: String) -> void:
	if property == "center_align":
		_sync_pillar_centralize_control()

func _is_detail_tool(tool: String) -> bool:
	return tool == TOOL_WINDOW or tool == TOOL_DOOR or tool == TOOL_HATCH or tool == TOOL_PILLAR or tool == TOOL_FENCE or tool == TOOL_PARAPET
