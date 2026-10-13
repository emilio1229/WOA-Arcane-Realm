extends Node3D

const GloamwickBuilder := preload("res://world/gloamwick.gd")
const CharacterVisualScript := preload("res://world/character_visual.gd")
const AnimatedCharacterScript := preload("res://world/animated_character.gd")
const WizardAppearanceScript := preload("res://world/wizard_appearance.gd")
const MinimapScript := preload("res://world/minimap.gd")
const Materials := preload("res://world/gloamwick_materials.gd")
const PROPS_OBJ := "res://Exports/OBJ/"

const MATHIAS_MODEL := "res://Assets/generated/mathias_opt.res"
const ENEMY_MODEL := "res://TripoModels/stone_golem_3d_model/stone_golem_3d_model.fbx"
const PLAYER_MODEL := "res://Assets/generated/wizard_opt.res"
const SPIRIT_MODEL := "res://Assets/generated/spirit_opt.res"
const BOSS_MODEL := "res://Assets/generated/boss_opt.res"
const SAVE_PATH := "user://woa_arcane_realm.cfg"
const WORLD_SEED := 730241
const WALK_SPEED := 5.2
const RUN_SPEED := 8.0
const JUMP_VELOCITY := 6.8
const GRAVITY := 18.0
const PATHS := ["Ember Mage", "Frostweaver", "Verdant Warden", "Storm Herald", "Voidcaller", "Sigilbinder"]
const ICONS := {
	"Gold Key": "res://Assets/generated/icon_key.png",
	"Silver Chalice": "res://Assets/generated/icon_chalice.png",
	"Violet Potion": "res://Assets/generated/icon_potion.png",
	"Bronze Sword": "res://Assets/generated/icon_sword.png",
	"Wooden Shield": "res://Assets/generated/icon_shield.png",
}

var player: CharacterBody3D
var player_spawn := Vector3(0.0, 0.0, 17.0)
var skirmish_timer := 0.0
var dialogue_full_text := ""
var dialogue_reveal := 0.0
var dialogue_typing := false
var _letter_timer := 0.0
var camera_pivot: Node3D
var game_camera: Camera3D
var player_visual: Node3D
var ui_layer: CanvasLayer
var menu_root: Control
var hud_root: Control
var dialogue_panel: PanelContainer
var dialogue_title: Label
var dialogue_body: Label
var dialogue_hint: Label
var objective_label: Label
var status_label: Label
var minimap: Minimap
var inventory_label: Label
var collectibles: Array[Node3D] = []
var collected_items: Array[String] = []
var name_input: LineEdit
var path_select: OptionButton
var path_note_label: Label
var dialogue_choice_trust: Button
var dialogue_choice_question: Button
var continue_button: Button
var player_name := "Apprentice"
var player_path := "Sigilbinder"
var yaw := 0.0
var pitch := -0.16
var started := false
var dialogue_open := false
var story_stage := 0
var collected_sigils := 0
var collected_sigil_names: Array[String] = []
var battle_cleared := false
var lore_discovered := false
var trust_mathias := true
var sigil_nodes: Array[Node3D] = []
var archive_wisp: Node3D
var enemy_nodes: Array[Node3D] = []
var enemy_hp: Dictionary = {}
var mathias: Node3D
var sanctuary_gate: Node3D
var last_message := ""
var save_data := ConfigFile.new()
var has_save := false
var loading_root: Control
var loading_bar: ProgressBar
var loading_status: Label
var loading_spinner: Label
var satchel_icons: Array[TextureRect] = []
var satchel_keys: Array[String] = []
var player_char_vis: CharacterVisual
var player_anim: AnimatedCharacter
var appearance: WizardAppearance = WizardAppearanceScript.new()
var preview_viewport: SubViewport
var preview_pivot: Node3D
var _player_moving := false
var _player_walk_phase := 0.0
var spin_nodes: Array[Node3D] = []
var flicker_lights: Array[OmniLight3D] = []
var _world_time := 0.0

func _ready() -> void:
	_build_ui()
	_load_save()
	_show_menu()
	_play_music(&"music_dusk", -19.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	_animate_world(delta)
	if preview_pivot != null and is_instance_valid(preview_pivot) and menu_root != null and menu_root.visible:
		preview_pivot.rotation.y += delta * 0.6
	if player_visual != null and is_instance_valid(player_visual):
		_player_walk_phase += delta * (10.0 if _player_moving else 1.8)
		if _player_moving:
			player_visual.position.y = absf(sin(_player_walk_phase)) * 0.06
			player_visual.rotation.z = sin(_player_walk_phase * 0.5) * 0.03
		else:
			player_visual.position.y = sin(_player_walk_phase) * 0.02
			player_visual.rotation.z = 0.0
	# Typewriter reveal for dialogue, with soft per-letter blips.
	if not dialogue_typing:
		return
	dialogue_reveal += delta * 62.0
	var count := int(dialogue_reveal)
	if count >= dialogue_full_text.length():
		dialogue_body.text = dialogue_full_text
		dialogue_typing = false
		return
	dialogue_body.text = dialogue_full_text.substr(0, count)
	_letter_timer -= delta
	if _letter_timer <= 0.0:
		_letter_timer = 0.045
		_play(&"text_letter", -20.0, randf_range(0.95, 1.12))

func _physics_process(delta: float) -> void:
	if started and not battle_cleared and mathias != null and is_instance_valid(mathias):
		_update_skirmish(delta)
	if not started or player == null or dialogue_open:
		if player != null:
			player.velocity.x = move_toward(player.velocity.x, 0.0, 22.0 * delta)
			player.velocity.z = move_toward(player.velocity.z, 0.0, 22.0 * delta)
			if not player.is_on_floor():
				player.velocity.y -= GRAVITY * delta
			player.move_and_slide()
		if player_char_vis != null and is_instance_valid(player_char_vis):
			player_char_vis.set_walking(false)
		if player_anim != null and is_instance_valid(player_anim):
			player_anim.set_locomotion(Vector2.ZERO, true, false, delta)
		_player_moving = false
		return

	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	elif Input.is_key_pressed(KEY_SPACE):
		player.velocity.y = JUMP_VELOCITY

	var input_vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vector.y += 1.0

	var direction := Vector3(input_vector.x, 0.0, input_vector.y)
	if direction.length_squared() > 0.0:
		direction = direction.normalized().rotated(Vector3.UP, yaw)
		var speed := RUN_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
		player.velocity.x = direction.x * speed
		player.velocity.z = direction.z * speed
		player.rotation.y = yaw
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, 24.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, 24.0 * delta)
	var running := Input.is_key_pressed(KEY_SHIFT)
	if player_anim != null and is_instance_valid(player_anim):
		player_anim.set_locomotion(input_vector, not running, false, delta)
	player.move_and_slide()
	_player_moving = direction.length_squared() > 0.0
	if player_char_vis != null and is_instance_valid(player_char_vis):
		player_char_vis.set_walking(_player_moving)
	_refresh_objective()

func _input(event: InputEvent) -> void:
	# Read mouse input before GUI controls can consume it. In the web build, the
	# full-screen HUD could swallow the click, leaving the camera permanently uncaptured.
	if not started:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not dialogue_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Use screen_relative so mouse-look sensitivity stays consistent in the browser at different sizes.
		yaw -= event.screen_relative.x * 0.0022
		pitch = clampf(pitch - event.screen_relative.y * 0.0016, -0.48, 0.32)
		if player != null:
			player.rotation.y = yaw
		if camera_pivot != null:
			camera_pivot.rotation.x = pitch
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_E:
			_interact()
		elif event.keycode == KEY_Q:
			_cast_arcane_pulse()

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	menu_root = Control.new()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(menu_root)

	var art := TextureRect.new()
	if ResourceLoader.exists("res://Assets/generated/menu_keyart.png"):
		art.texture = load("res://Assets/generated/menu_keyart.png")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu_root.add_child(art)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.015, 0.06, 0.58)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	menu_root.add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	margin.add_child(columns)

	var story_side := VBoxContainer.new()
	story_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	story_side.alignment = BoxContainer.ALIGNMENT_CENTER
	story_side.add_theme_constant_override("separation", 18)
	columns.add_child(story_side)

	var sigil_mark := Label.new()
	sigil_mark.text = "✧"
	sigil_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sigil_mark.add_theme_font_size_override("font_size", 58)
	sigil_mark.add_theme_color_override("font_color", Color(0.79, 0.55, 1.0))
	story_side.add_child(sigil_mark)

	var overline := Label.new()
	overline.text = "THE WIZARDS OF ARK PRESENT"
	overline.add_theme_font_size_override("font_size", 12)
	overline.add_theme_color_override("font_color", Color(0.75, 0.56, 0.92))
	story_side.add_child(overline)

	var title := Label.new()
	title.text = "ARCANE\nREALM"
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", Color(0.94, 0.84, 1.0))
	title.add_theme_constant_override("line_spacing", -10)
	story_side.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "CHRONICLES OF THE HOLLOW CROWN"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.82, 0.62, 1.0))
	story_side.add_child(subtitle)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(120, 2)
	divider.color = Color(0.54, 0.3, 0.76, 0.9)
	story_side.add_child(divider)

	var lore := Label.new()
	lore.text = "The wards are failing. Old Sigils stir beneath forgotten stone. Somewhere beyond Gloamwick, a crown erased from history is beginning to remember its name."
	lore.custom_minimum_size = Vector2(300, 0)
	lore.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.add_theme_font_size_override("font_size", 19)
	lore.add_theme_color_override("font_color", Color(0.81, 0.76, 0.88))
	story_side.add_child(lore)

	var chapter := Label.new()
	chapter.text = "CHAPTER I   /   GLOAMWICK"
	chapter.add_theme_font_size_override("font_size", 12)
	chapter.add_theme_color_override("font_color", Color(0.64, 0.54, 0.75))
	story_side.add_child(chapter)

	# Middle column: the live 3D preview of the wizard being created.
	var preview_wrap := VBoxContainer.new()
	preview_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview_wrap.add_theme_constant_override("separation", 8)
	columns.add_child(preview_wrap)

	var preview_panel := PanelContainer.new()
	preview_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.032, 0.09, 0.97), Color(0.48, 0.29, 0.67)))
	preview_wrap.add_child(preview_panel)

	var preview_container := SubViewportContainer.new()
	preview_container.custom_minimum_size = Vector2(240, 380)
	preview_container.stretch = true
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(preview_container)
	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(240, 380)
	preview_viewport.transparent_bg = true
	preview_viewport.own_world_3d = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_container.add_child(preview_viewport)

	var preview_env := WorldEnvironment.new()
	var pe := Environment.new()
	pe.background_mode = Environment.BG_COLOR
	pe.background_color = Color(0.05, 0.03, 0.09, 0.0)
	pe.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	pe.ambient_light_color = Color(0.55, 0.5, 0.7)
	pe.ambient_light_energy = 0.85
	preview_env.environment = pe
	preview_viewport.add_child(preview_env)

	var preview_light := DirectionalLight3D.new()
	preview_light.rotation_degrees = Vector3(-28, -42, 0)
	preview_light.light_energy = 1.25
	preview_viewport.add_child(preview_light)

	var preview_cam := Camera3D.new()
	preview_cam.position = Vector3(0, 1.15, 2.9)
	preview_cam.rotation.x = -0.04
	preview_cam.fov = 52.0
	preview_cam.current = true
	preview_viewport.add_child(preview_cam)

	preview_pivot = Node3D.new()
	preview_viewport.add_child(preview_pivot)
	_refresh_preview()

	var preview_caption := Label.new()
	preview_caption.text = "YOUR WIZARD"
	preview_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_caption.add_theme_font_size_override("font_size", 12)
	preview_caption.add_theme_color_override("font_color", Color(0.73, 0.55, 0.9))
	preview_wrap.add_child(preview_caption)

	var form_wrap := CenterContainer.new()
	form_wrap.custom_minimum_size = Vector2(410, 0)
	columns.add_child(form_wrap)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(390, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.032, 0.09, 0.97), Color(0.48, 0.29, 0.67)))
	form_wrap.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)

	var menu_heading := Label.new()
	menu_heading.text = "CREATE YOUR WIZARD"
	menu_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_heading.add_theme_font_size_override("font_size", 23)
	menu_heading.add_theme_color_override("font_color", Color(0.93, 0.83, 1.0))
	layout.add_child(menu_heading)

	var menu_note := Label.new()
	menu_note.text = "Your chronicle begins when you awaken."
	menu_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_note.add_theme_font_size_override("font_size", 13)
	menu_note.add_theme_color_override("font_color", Color(0.72, 0.64, 0.81))
	layout.add_child(menu_note)

	layout.add_child(HSeparator.new())

	var name_label := Label.new()
	name_label.text = "WIZARD NAME"
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.81, 0.69, 0.94))
	layout.add_child(name_label)

	name_input = LineEdit.new()
	name_input.placeholder_text = "What shall the Realm call you?"
	name_input.text = player_name if player_name != "Apprentice" else ""
	name_input.custom_minimum_size = Vector2(0, 44)
	name_input.max_length = 24
	name_input.add_theme_font_size_override("font_size", 16)
	name_input.add_theme_stylebox_override("normal", _panel_style(Color(0.025, 0.018, 0.045), Color(0.31, 0.22, 0.4)))
	layout.add_child(name_input)

	var path_label := Label.new()
	path_label.text = "CHOOSE YOUR ARCANE PATH"
	path_label.add_theme_font_size_override("font_size", 12)
	path_label.add_theme_color_override("font_color", Color(0.81, 0.69, 0.94))
	layout.add_child(path_label)

	path_select = OptionButton.new()
	path_select.custom_minimum_size = Vector2(0, 44)
	for path_name in PATHS:
		path_select.add_item(path_name)
	path_select.select(5)
	path_select.add_theme_font_size_override("font_size", 15)
	layout.add_child(path_select)

	path_note_label = Label.new()
	path_note_label.text = "Your path shapes your legend. Your choices shape the Realm."
	path_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	path_note_label.add_theme_font_size_override("font_size", 12)
	path_note_label.add_theme_color_override("font_color", Color(0.66, 0.59, 0.75))
	layout.add_child(path_note_label)
	path_select.item_selected.connect(_on_path_selected)
	_on_path_selected(path_select.selected)

	_make_swatch_row(layout, "ROBE COLOUR", WizardAppearanceScript.ROBES, func(c: Color) -> void:
		appearance.robe = c
		_refresh_preview())
	_make_swatch_row(layout, "ACCENT", WizardAppearanceScript.ACCENTS, func(c: Color) -> void:
		appearance.accent = c
		_refresh_preview())
	_make_swatch_row(layout, "SKIN TONE", WizardAppearanceScript.SKINS, func(c: Color) -> void:
		appearance.skin = c
		_refresh_preview())

	var hat_row := HBoxContainer.new()
	hat_row.add_theme_constant_override("separation", 6)
	var hat_label := Label.new()
	hat_label.text = "HEAD"
	hat_label.custom_minimum_size = Vector2(110, 0)
	hat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hat_label.add_theme_font_size_override("font_size", 12)
	hat_label.add_theme_color_override("font_color", Color(0.81, 0.69, 0.94))
	hat_row.add_child(hat_label)
	for option in [["Hat", 0], ["Hood", 1], ["Bare", 2]]:
		var hb := _make_button(str(option[0]), Color(0.24, 0.16, 0.36))
		hb.custom_minimum_size = Vector2(76, 34)
		hb.pressed.connect(func() -> void:
			appearance.hat = int(option[1])
			_refresh_preview())
		hat_row.add_child(hb)
	layout.add_child(hat_row)

	var staff_check := CheckButton.new()
	staff_check.text = "CARRY A STAFF"
	staff_check.button_pressed = appearance.staff
	staff_check.add_theme_font_size_override("font_size", 12)
	staff_check.toggled.connect(func(on: bool) -> void:
		appearance.staff = on
		_refresh_preview())
	layout.add_child(staff_check)

	var begin_button := _make_button("✦   BEGIN YOUR JOURNEY", Color(0.34, 0.15, 0.52))
	begin_button.pressed.connect(_start_new_game)
	layout.add_child(begin_button)

	continue_button = _make_button("CONTINUE CHRONICLE", Color(0.16, 0.105, 0.25))
	continue_button.pressed.connect(_continue_game)
	layout.add_child(continue_button)

	var controls := Label.new()
	controls.text = "WASD Move  •  Space Jump  •  Shift Run\nE Interact  •  Q Arcane Pulse  •  Esc Release Mouse"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_font_size_override("font_size", 11)
	controls.add_theme_color_override("font_color", Color(0.59, 0.53, 0.68))
	layout.add_child(controls)

	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.visible = false
	ui_layer.add_child(hud_root)

	var objective_panel := PanelContainer.new()
	objective_panel.position = Vector2(20, 18)
	objective_panel.custom_minimum_size = Vector2(390, 68)
	objective_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.02, 0.07, 0.88), Color(0.38, 0.22, 0.57)))
	hud_root.add_child(objective_panel)

	var objective_box := VBoxContainer.new()
	objective_box.add_theme_constant_override("separation", 4)
	objective_panel.add_child(objective_box)

	var objective_heading := Label.new()
	objective_heading.text = "CURRENT CHRONICLE"
	objective_heading.add_theme_font_size_override("font_size", 11)
	objective_heading.add_theme_color_override("font_color", Color(0.73, 0.55, 0.9))
	objective_box.add_child(objective_heading)

	objective_label = Label.new()
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 15)
	objective_box.add_child(objective_label)

	status_label = Label.new()
	status_label.position = Vector2(20, 176)
	status_label.custom_minimum_size = Vector2(480, 34)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.83, 1.0))
	hud_root.add_child(status_label)

	inventory_label = Label.new()
	inventory_label.position = Vector2(20, 208)
	inventory_label.custom_minimum_size = Vector2(520, 28)
	inventory_label.add_theme_font_size_override("font_size", 13)
	inventory_label.add_theme_color_override("font_color", Color(0.85, 0.93, 0.78))
	hud_root.add_child(inventory_label)

	minimap = MinimapScript.new()
	minimap.name = "Minimap"
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -196.0
	minimap.offset_right = -16.0
	minimap.offset_top = 18.0
	minimap.offset_bottom = 198.0
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(minimap)

	dialogue_panel = PanelContainer.new()
	dialogue_panel.anchor_left = 0.08
	dialogue_panel.anchor_right = 0.92
	dialogue_panel.anchor_top = 0.56
	dialogue_panel.anchor_bottom = 0.97
	dialogue_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.018, 0.07, 0.97), Color(0.65, 0.38, 0.88)))
	dialogue_panel.visible = false
	hud_root.add_child(dialogue_panel)

	var dialogue_layout := VBoxContainer.new()
	dialogue_layout.add_theme_constant_override("separation", 8)
	dialogue_panel.add_child(dialogue_layout)

	dialogue_title = Label.new()
	dialogue_title.add_theme_font_size_override("font_size", 21)
	dialogue_title.add_theme_color_override("font_color", Color(0.91, 0.78, 1.0))
	dialogue_layout.add_child(dialogue_title)

	dialogue_body = Label.new()
	dialogue_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_body.clip_text = true
	dialogue_body.add_theme_font_size_override("font_size", 14)
	dialogue_layout.add_child(dialogue_body)

	dialogue_hint = Label.new()
	dialogue_hint.text = "Press E or select Continue"
	dialogue_hint.add_theme_font_size_override("font_size", 12)
	dialogue_hint.add_theme_color_override("font_color", Color(0.72, 0.65, 0.8))
	dialogue_layout.add_child(dialogue_hint)

	dialogue_choice_trust = _make_button("I TRUST YOU. SHOW ME THE SIGILS.", Color(0.22, 0.16, 0.34))
	dialogue_choice_trust.visible = false
	dialogue_choice_trust.pressed.connect(_choose_trust_mathias)
	dialogue_layout.add_child(dialogue_choice_trust)

	dialogue_choice_question = _make_button("WHAT ARE YOU HIDING, MATHIAS?", Color(0.22, 0.16, 0.34))
	dialogue_choice_question.visible = false
	dialogue_choice_question.pressed.connect(_choose_question_mathias)
	dialogue_layout.add_child(dialogue_choice_question)

	var dialogue_button := _make_button("CONTINUE", Color(0.31, 0.13, 0.48))
	dialogue_button.pressed.connect(_advance_dialogue)
	dialogue_layout.add_child(dialogue_button)

	# --- Player panel: name, path and chapter, under the objective. ---
	var player_panel := PanelContainer.new()
	player_panel.position = Vector2(20, 96)
	player_panel.custom_minimum_size = Vector2(390, 0)
	player_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.02, 0.07, 0.82), Color(0.30, 0.18, 0.45)))
	hud_root.add_child(player_panel)

	var player_box := VBoxContainer.new()
	player_box.add_theme_constant_override("separation", 2)
	player_panel.add_child(player_box)

	var name_line := Label.new()
	name_line.name = "PlayerNameLine"
	name_line.add_theme_font_size_override("font_size", 17)
	name_line.add_theme_color_override("font_color", Color(0.95, 0.86, 1.0))
	player_box.add_child(name_line)

	var path_line := Label.new()
	path_line.name = "PlayerPathLine"
	path_line.add_theme_font_size_override("font_size", 12)
	path_line.add_theme_color_override("font_color", Color(0.74, 0.62, 0.9))
	player_box.add_child(path_line)

	# --- Satchel: collectible item icons across the bottom-left. ---
	var satchel := PanelContainer.new()
	satchel.anchor_top = 1.0
	satchel.anchor_bottom = 1.0
	satchel.offset_left = 20.0
	satchel.offset_top = -94.0
	satchel.offset_bottom = -20.0
	satchel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.02, 0.07, 0.86), Color(0.38, 0.22, 0.57)))
	hud_root.add_child(satchel)

	var satchel_row := HBoxContainer.new()
	satchel_row.add_theme_constant_override("separation", 6)
	satchel.add_child(satchel_row)

	var satchel_tag := Label.new()
	satchel_tag.text = "SATCHEL"
	satchel_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	satchel_tag.add_theme_font_size_override("font_size", 11)
	satchel_tag.add_theme_color_override("font_color", Color(0.73, 0.55, 0.9))
	satchel_row.add_child(satchel_tag)

	for item_key in ICONS.keys():
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(58, 58)
		slot.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.012, 0.04, 0.92), Color(0.30, 0.19, 0.44)))
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(46, 46)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = load(ICONS[item_key])
		ic.modulate = Color(0.6, 0.6, 0.65, 0.16)
		slot.add_child(ic)
		satchel_row.add_child(slot)
		satchel_icons.append(ic)
		satchel_keys.append(item_key)

	# --- Cinematic loading screen: use the project's key art as the realm backdrop. ---
	loading_root = Control.new()
	loading_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_root.visible = false
	loading_root.mouse_filter = Control.MOUSE_FILTER_STOP
	loading_root.clip_contents = true
	ui_layer.add_child(loading_root)

	var lveil := ColorRect.new()
	lveil.color = Color(0.015, 0.008, 0.035, 1.0)
	lveil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_root.add_child(lveil)

	if ResourceLoader.exists("res://Assets/generated/menu_keyart.png"):
		var lart := TextureRect.new()
		lart.texture = load("res://Assets/generated/menu_keyart.png")
		lart.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		lart.modulate = Color(1.0, 0.92, 1.0, 0.78)
		lart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		loading_root.add_child(lart)

	# Deep violet veil keeps the key art atmospheric while leaving it visible.
	var lveil2 := ColorRect.new()
	lveil2.color = Color(0.025, 0.012, 0.055, 0.48)
	lveil2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lveil2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_root.add_child(lveil2)

	var top_brand := Label.new()
	top_brand.text = "✧   W I Z A R D S   O F   A R K"
	top_brand.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_brand.offset_left = 42.0
	top_brand.offset_top = 28.0
	top_brand.offset_right = -42.0
	top_brand.offset_bottom = 56.0
	top_brand.add_theme_font_size_override("font_size", 13)
	top_brand.add_theme_color_override("font_color", Color(0.82, 0.67, 1.0, 0.95))
	top_brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_root.add_child(top_brand)

	var lcenter := CenterContainer.new()
	lcenter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lcenter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_root.add_child(lcenter)

	var lpanel := PanelContainer.new()
	lpanel.custom_minimum_size = Vector2(620, 0)
	lpanel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.012, 0.055, 0.82), Color(0.52, 0.34, 0.72, 0.78)))
	lcenter.add_child(lpanel)

	var lcol := VBoxContainer.new()
	lcol.add_theme_constant_override("separation", 12)
	lcol.alignment = BoxContainer.ALIGNMENT_CENTER
	lcol.custom_minimum_size = Vector2(560, 0)
	lpanel.add_child(lcol)

	loading_spinner = Label.new()
	loading_spinner.text = "✧"
	loading_spinner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_spinner.add_theme_font_size_override("font_size", 52)
	loading_spinner.add_theme_color_override("font_color", Color(0.84, 0.64, 1.0))
	lcol.add_child(loading_spinner)

	var ltitle := Label.new()
	ltitle.text = "ARCANE REALM"
	ltitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ltitle.add_theme_font_size_override("font_size", 42)
	ltitle.add_theme_color_override("font_color", Color(0.97, 0.91, 1.0))
	ltitle.add_theme_constant_override("outline_size", 2)
	ltitle.add_theme_color_override("font_outline_color", Color(0.08, 0.025, 0.12, 0.9))
	lcol.add_child(ltitle)

	var lsubtitle := Label.new()
	lsubtitle.text = "CHRONICLES OF THE HOLLOW CROWN"
	lsubtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lsubtitle.add_theme_font_size_override("font_size", 12)
	lsubtitle.add_theme_color_override("font_color", Color(0.77, 0.63, 0.91))
	lcol.add_child(lsubtitle)

	var ldivider_wrap := CenterContainer.new()
	lcol.add_child(ldivider_wrap)
	var ldivider := ColorRect.new()
	ldivider.custom_minimum_size = Vector2(150, 2)
	ldivider.color = Color(0.66, 0.42, 0.92, 0.9)
	ldivider_wrap.add_child(ldivider)

	var lchapter := Label.new()
	lchapter.text = "CHAPTER I   •   THE BELLS OF GLOAMWICK"
	lchapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lchapter.add_theme_font_size_override("font_size", 13)
	lchapter.add_theme_color_override("font_color", Color(0.92, 0.83, 1.0))
	lcol.add_child(lchapter)

	var lbar_wrap := CenterContainer.new()
	lcol.add_child(lbar_wrap)
	loading_bar = ProgressBar.new()
	loading_bar.custom_minimum_size = Vector2(500, 12)
	loading_bar.min_value = 0.0
	loading_bar.max_value = 100.0
	loading_bar.value = 0.0
	loading_bar.show_percentage = false
	loading_bar.add_theme_stylebox_override("background", _panel_style(Color(0.055, 0.025, 0.09, 0.95), Color(0.28, 0.17, 0.4, 0.9)))
	loading_bar.add_theme_stylebox_override("fill", _panel_style(Color(0.54, 0.3, 0.78, 1.0), Color(0.83, 0.63, 1.0, 1.0)))
	lbar_wrap.add_child(loading_bar)

	loading_status = Label.new()
	loading_status.text = "Awakening the wards…"
	loading_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_status.add_theme_font_size_override("font_size", 13)
	loading_status.add_theme_color_override("font_color", Color(0.79, 0.72, 0.88))
	lcol.add_child(loading_status)

	var lfooter := Label.new()
	lfooter.text = "THE REALM REMEMBERS EVERY CHOICE"
	lfooter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lfooter.offset_left = 32.0
	lfooter.offset_top = -48.0
	lfooter.offset_right = -32.0
	lfooter.offset_bottom = -22.0
	lfooter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lfooter.add_theme_font_size_override("font_size", 10)
	lfooter.add_theme_color_override("font_color", Color(0.72, 0.62, 0.83, 0.9))
	lfooter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_root.add_child(lfooter)
func _on_path_selected(index: int) -> void:
	if path_note_label == null or index < 0 or index >= PATHS.size():
		return
	var descriptions := {
		"Ember Mage": "Fire magic • heavy damage that burns through riftbound defenses.",
		"Frostweaver": "Frost magic • measured spells that weaken enemies and control the fight.",
		"Verdant Warden": "Life magic • resilient nature magic and protective force.",
		"Storm Herald": "Storm magic • rapid strikes that can leap between nearby foes.",
		"Voidcaller": "Void magic • dangerous, focused power drawn from the edge of the Rift.",
		"Sigilbinder": "Sigil magic • balanced arcana attuned to ancient wards and relics."
	}
	path_note_label.text = descriptions.get(PATHS[index], "Your path shapes your legend. Your choices shape the Realm.")

func _show_menu() -> void:
	menu_root.visible = true
	hud_root.visible = false
	if continue_button != null:
		continue_button.disabled = not has_save
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _start_new_game() -> void:
	var entered_name := name_input.text.strip_edges()
	player_name = entered_name if entered_name != "" else "Apprentice"
	player_path = PATHS[path_select.selected] if path_select.selected >= 0 else "Sigilbinder"
	story_stage = 0
	collected_sigils = 0
	collected_sigil_names.clear()
	battle_cleared = false
	lore_discovered = false
	trust_mathias = true
	_save_game()
	_enter_game(true)

func _continue_game() -> void:
	if not has_save:
		return
	player_name = str(save_data.get_value("player", "name", "Apprentice"))
	player_path = str(save_data.get_value("player", "path", "Sigilbinder"))
	story_stage = int(save_data.get_value("progress", "stage", 0))
	collected_sigils = int(save_data.get_value("progress", "sigils", 0))
	_enter_game(false)

func _enter_game(show_intro: bool) -> void:
	# Rebuilding a new or continued chronicle must not retain stale nodes from a previous run.
	sigil_nodes.clear()
	enemy_nodes.clear()
	enemy_hp.clear()
	mathias = null
	sanctuary_gate = null
	archive_wisp = null
	menu_root.visible = false
	hud_root.visible = false
	started = false
	await _show_loading()
	_build_world()
	_build_player()
	_refresh_objective()
	_refresh_player_panel()
	hud_root.visible = true
	await _hide_loading()
	started = true
	if show_intro:
		_show_dialogue("THE BELLS OF GLOAMWICK", "“Awaken, " + player_name + "… You have reached Gloamwick beneath a violet sky that grows dimmer by the hour. The market stalls stand abandoned, the rune well has begun to whisper, and every lantern burns as though it fears the dark. Beyond the square, a Battle Mage named Mathias is holding the southern ward against the riftbound. If it falls, the town will be swallowed before dawn. Follow the lamps through the market and help him.”", "Enter Gloamwick • Reach Mathias beyond the market")
	else:
		_show_dialogue("THE BELLS OF GLOAMWICK", "Your Chronicle stirs again. The bells are silent, the market is deserted, and the southern ward still flickers. The rune lamps lead through the square toward Mathias and the riftbound.", "Continue through the market to Mathias")

func _build_world() -> void:
	for child in get_children():
		if child == ui_layer:
			continue
		child.queue_free()

	# The whole settlement environment is assembled by the Gloamwick builder,
	# which reports the anchor points the encounter is placed on.
	var gloamwick := GloamwickBuilder.new()
	gloamwick.name = "Gloamwick"
	add_child(gloamwick)
	gloamwick.build()
	var anchors: Dictionary = gloamwick.get_anchors()
	player_spawn = anchors.get("player_spawn", Vector3(0.0, 0.0, 17.0))
	if minimap != null:
		var marks: Array[Dictionary] = [
			{"pos": anchors.get("mathias", Vector3.ZERO), "color": Color(0.95, 0.6, 0.2)},
			{"pos": anchors.get("well", Vector3.ZERO), "color": Color(0.35, 0.8, 1.0)},
			{"pos": anchors.get("gate_sigil", Vector3.ZERO), "color": Color(0.65, 0.35, 1.0)},
			{"pos": anchors.get("tower", Vector3(0.0, 0.0, -116.0)), "color": Color(0.95, 0.25, 0.6)},
		]
		minimap.set_pois(marks)

	# Interactable lore wisp at the forgotten shrine.
	archive_wisp = _make_sigil(anchors.get("archive_wisp", Vector3(10.5, 2.0, -45)), Color(0.36, 0.86, 0.95), 0.42)
	archive_wisp.name = "Archive Wisp"
	archive_wisp.visible = not lore_discovered
	add_child(archive_wisp)

	# The sanctuary gate rune.
	sanctuary_gate = _make_sigil(anchors.get("gate_sigil", Vector3(0.0, 2.4, -61.45)), Color(0.38, 0.12, 0.75), 2.1)
	sanctuary_gate.name = "Sigil Sanctuary Gate"
	add_child(sanctuary_gate)

	# The rune well's glowing heart (its stonework is part of the environment).
	var well_rune := _make_sigil(anchors.get("well", Vector3(0.0, 1.15, -16.5)), Color(0.34, 0.76, 0.98), 0.42, false)
	well_rune.name = "Gloamwick Rune Well"
	add_child(well_rune)

	# Mathias holds the southern ward, modelled with his own 3D asset.
	mathias = _spawn_character(MATHIAS_MODEL, "Mathias", anchors.get("mathias", Vector3(0.0, 0.0, -35.0)), 2.15, 0.0)
	if not battle_cleared:
		var enemy_positions: Array = anchors.get("enemies", [])
		# These creature models are ~1.9M triangles each, so only two are active
		# to stay within this GPU's budget.
		var enemy_count: int = mini(enemy_positions.size(), 2)
		for i in range(enemy_count):
			var enemy := _spawn_character(SPIRIT_MODEL, "Riftbound " + str(i + 1), enemy_positions[i], 2.4, PI)
			enemy_nodes.append(enemy)
			enemy_hp[enemy.get_instance_id()] = 2

	# The three seals of the Sigil Sanctuary.
	var sigil_positions: Array = anchors.get("sigils", [Vector3(-8.0, 1.1, -48.0), Vector3(8.0, 1.1, -48.0), Vector3(0.0, 1.1, -54.0)])
	var sigil_names := ["Dawn", "Dusk", "Heart"]
	var sigil_colors := [Color(0.98, 0.66, 0.24), Color(0.52, 0.35, 0.95), Color(0.28, 0.85, 0.72)]
	for i in range(3):
		var shrine := _make_sigil(sigil_positions[i], sigil_colors[i], 0.75)
		shrine.name = sigil_names[i] + " Sigil"
		shrine.set_meta("sigil_name", sigil_names[i])
		shrine.visible = not collected_sigil_names.has(sigil_names[i])
		sigil_nodes.append(shrine)
		add_child(shrine)

	# Scattered quest items and gear to discover.
	collectibles.clear()
	_build_collectibles()
	_refresh_inventory()

	# Register everything that should gently spin/float, and every omni light
	# that should flicker, so the world reads as alive without baked animation.
	spin_nodes.clear()
	flicker_lights.clear()
	_register_spin(archive_wisp)
	_register_spin(sanctuary_gate)
	_register_spin(well_rune)
	for sigil_node in sigil_nodes:
		_register_spin(sigil_node)
	for item_node in collectibles:
		_register_spin(item_node)
	_collect_lights(gloamwick)

func _build_collectibles() -> void:
	var items := [
		{"name": "Gold Key", "kind": "relic", "obj": "Key_Gold", "pos": Vector3(-9.0, 0.7, -6.5)},
		{"name": "Silver Chalice", "kind": "relic", "obj": "Chalice", "pos": Vector3(9.0, 0.9, -6.5)},
		{"name": "Violet Potion", "kind": "relic", "obj": "Potion_2", "pos": Vector3(0.0, 0.7, -21.0)},
		{"name": "Bronze Sword", "kind": "gear", "obj": "Sword_Bronze", "pos": Vector3(5.0, 0.7, 3.0)},
		{"name": "Wooden Shield", "kind": "gear", "obj": "Shield_Wooden", "pos": Vector3(-5.0, 0.7, 3.0)},
	]
	for entry in items:
		var node := _make_collectible(PROPS_OBJ + str(entry["obj"]) + ".obj", entry["pos"], str(entry["name"]), str(entry["kind"]))
		collectibles.append(node)
		add_child(node)

func _make_collectible(obj_path: String, pos: Vector3, item_name: String, kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Item_" + item_name
	root.position = pos
	root.set_meta("item_name", item_name)
	root.set_meta("item_kind", kind)
	if ResourceLoader.exists(obj_path):
		var mesh := load(obj_path) as Mesh
		if mesh != null:
			Materials.apply_to_mesh(mesh)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			root.add_child(mi)
	var tint := Color(1.0, 0.85, 0.4) if kind == "gear" else Color(0.55, 0.9, 1.0)
	var glow := _make_sigil(Vector3.ZERO, tint, 0.26, false)
	root.add_child(glow)
	return root

func _nearest_collectible() -> Node3D:
	return _nearest_node(collectibles)

func _refresh_inventory() -> void:
	if inventory_label != null:
		if collected_items.is_empty():
			inventory_label.text = "SATCHEL  •  nothing gathered yet"
		else:
			inventory_label.text = "SATCHEL  •  " + ", ".join(collected_items)
	for i in satchel_icons.size():
		var has_item: bool = collected_items.has(satchel_keys[i])
		satchel_icons[i].modulate = Color(1, 1, 1, 1) if has_item else Color(0.6, 0.6, 0.65, 0.16)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "PlayerWizard"
	player.position = player_spawn
	player.floor_snap_length = 0.35
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.85
	collision.shape = capsule
	collision.position.y = 0.93
	player.add_child(collision)

	# The player must be in the tree before the rig resolves its animation paths.
	add_child(player)
	player_visual = Node3D.new()
	player_visual.name = "WizardVisual"
	player.add_child(player_visual)
	player_char_vis = null
	player_anim = null
	# The player is the addon's real rigged human (real human mesh, real walk/
	# run/jump animations), dressed with the wizard's hat and staff.
	player_char_vis = null
	player_anim = null
	var rig: AnimatedCharacter = AnimatedCharacterScript.new()
	player_visual.add_child(rig)
	if rig.setup(player):
		player_anim = rig
		rig.set_tint(appearance.skin)
		_attach_wizard_extras(rig)
	else:
		rig.queue_free()
		player_visual.add_child(appearance.build())
	if minimap != null:
		minimap.target = player

	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 1.5, 0)
	player.add_child(camera_pivot)
	game_camera = Camera3D.new()
	game_camera.position = Vector3(0, 2.4, 7.0)
	game_camera.rotation.x = 0.19
	game_camera.current = true
	game_camera.fov = 72.0
	camera_pivot.add_child(game_camera)
	camera_pivot.rotation.x = pitch

## Spawn a character driven by an imported 3D model, falling back to the
## procedural figure if the model is unavailable.
func _spawn_character(scene_path: String, char_name: String, pos: Vector3, height: float, face_yaw: float) -> Node3D:
	var root := Node3D.new()
	root.name = char_name
	root.position = pos
	root.rotation.y = face_yaw
	var vis: CharacterVisual = CharacterVisualScript.new()
	var modeled := vis.setup(scene_path, height, PI)
	if modeled:
		root.add_child(vis)
		root.set_meta("visual", vis)
	else:
		_add_person_visual(root, Color(0.16, 0.11, 0.28), Color(0.8, 0.72, 0.92), true)
	add_child(root)
	return root

## Play a sound through the Any Audio Manager autoload, if present.
func _play(key: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_sfx"):
		am.play_sfx(key, volume_db, pitch_scale)

func _play_music(key: StringName, volume_db: float = -18.0) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_music"):
		am.play_music(key, true, volume_db)

func _update_skirmish(delta: float) -> void:
	skirmish_timer -= delta
	if skirmish_timer > 0.0:
		return
	skirmish_timer = randf_range(0.8, 1.6)
	if mathias.has_meta("visual"):
		var m_vis = mathias.get_meta("visual")
		if m_vis != null and m_vis.has_method("attack"):
			m_vis.attack()
	if not enemy_nodes.is_empty():
		var enemy: Node3D = enemy_nodes[randi() % enemy_nodes.size()]
		if is_instance_valid(enemy) and enemy.has_meta("visual"):
			var e_vis = enemy.get_meta("visual")
			if e_vis != null and e_vis.has_method("attack"):
				e_vis.attack()
	_play(&"ui_confirm", -16.0, randf_range(0.9, 1.15))

func _build_person(person_name: String, pos: Vector3, robe_color: Color, glow_color: Color, is_mage: bool) -> Node3D:
	var person := Node3D.new()
	person.name = person_name
	person.position = pos
	_add_person_visual(person, robe_color, glow_color, is_mage)
	add_child(person)
	return person

func _add_person_visual(parent: Node3D, robe_color: Color, face_color: Color, is_mage: bool) -> void:
	# Layered silhouette: broad hem, fitted torso, sleeves, sash and a compact hat.
	# Keeping the character built from low-poly meshes avoids missing external model imports.
	var robe := MeshInstance3D.new()
	var robe_mesh := CylinderMesh.new()
	robe_mesh.top_radius = 0.27
	robe_mesh.bottom_radius = 0.55
	robe_mesh.height = 1.12
	robe.mesh = robe_mesh
	robe.position = Vector3(0, 0.66, 0)
	robe.material_override = _material(robe_color)
	parent.add_child(robe)

	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.27
	torso_mesh.height = 0.82
	torso.mesh = torso_mesh
	torso.position = Vector3(0, 1.12, 0)
	torso.material_override = _material(robe_color.lightened(0.08))
	parent.add_child(torso)

	var cape := MeshInstance3D.new()
	var cape_mesh := SphereMesh.new()
	cape_mesh.radius = 0.43
	cape_mesh.height = 1.2
	cape.mesh = cape_mesh
	cape.position = Vector3(0, 0.96, 0.18)
	cape.scale = Vector3(1.0, 1.0, 0.34)
	cape.material_override = _material(robe_color.darkened(0.32))
	parent.add_child(cape)

	for side in [-1.0, 1.0]:
		var sleeve := MeshInstance3D.new()
		var sleeve_mesh := CylinderMesh.new()
		sleeve_mesh.top_radius = 0.105
		sleeve_mesh.bottom_radius = 0.14
		sleeve_mesh.height = 0.72
		sleeve.mesh = sleeve_mesh
		sleeve.position = Vector3(side * 0.37, 1.02, -0.005)
		sleeve.rotation.z = side * -0.22
		sleeve.material_override = _material(robe_color.darkened(0.08))
		parent.add_child(sleeve)

		var hand := _make_sphere(Vector3(side * 0.43, 0.65, -0.035), 0.105, Color(0.52, 0.36, 0.31) if is_mage else robe_color.darkened(0.45))
		hand.scale = Vector3(0.82, 1.0, 0.82)
		parent.add_child(hand)

		var boot := MeshInstance3D.new()
		var boot_mesh := SphereMesh.new()
		boot_mesh.radius = 0.17
		boot_mesh.height = 0.25
		boot.mesh = boot_mesh
		boot.position = Vector3(side * 0.19, 0.12, -0.055)
		boot.scale = Vector3(1.0, 0.72, 1.25)
		boot.material_override = _material(Color(0.055, 0.035, 0.075))
		parent.add_child(boot)

	var sash := MeshInstance3D.new()
	var sash_mesh := TorusMesh.new()
	sash_mesh.inner_radius = 0.265
	sash_mesh.outer_radius = 0.315
	sash.mesh = sash_mesh
	sash.position.y = 0.79
	sash.material_override = _material(Color(0.68, 0.43, 0.2) if is_mage else Color(0.19, 0.14, 0.24))
	parent.add_child(sash)

	var face := MeshInstance3D.new()
	var face_mesh := SphereMesh.new()
	face_mesh.radius = 0.235
	face_mesh.height = 0.47
	face.mesh = face_mesh
	face.position = Vector3(0, 1.57, -0.045)
	face.material_override = _material(Color(0.58, 0.42, 0.38) if is_mage else Color(0.055, 0.028, 0.085))
	parent.add_child(face)

	if is_mage:
		# A smaller brim and tapered crown read as a hat instead of a floating cone.
		var brim := MeshInstance3D.new()
		var brim_mesh := CylinderMesh.new()
		brim_mesh.top_radius = 0.31
		brim_mesh.bottom_radius = 0.34
		brim_mesh.height = 0.075
		brim.mesh = brim_mesh
		brim.position.y = 1.82
		brim.material_override = _material(robe_color.darkened(0.1))
		parent.add_child(brim)

		var hat := MeshInstance3D.new()
		var hat_mesh := CylinderMesh.new()
		hat_mesh.top_radius = 0.035
		hat_mesh.bottom_radius = 0.245
		hat_mesh.height = 0.52
		hat.mesh = hat_mesh
		hat.position.y = 2.105
		hat.rotation.z = -0.08
		hat.material_override = _material(robe_color.darkened(0.12))
		parent.add_child(hat)

		var hat_band := MeshInstance3D.new()
		var band_mesh := TorusMesh.new()
		band_mesh.inner_radius = 0.222
		band_mesh.outer_radius = 0.245
		hat_band.mesh = band_mesh
		hat_band.position.y = 1.91
		hat_band.material_override = _material(face_color, true)
		parent.add_child(hat_band)
	else:
		# Mathias' shadowed hood and bright eyes give him a distinct battle-mage shape.
		var hood := MeshInstance3D.new()
		var hood_mesh := SphereMesh.new()
		hood_mesh.radius = 0.29
		hood_mesh.height = 0.42
		hood.mesh = hood_mesh
		hood.position = Vector3(0, 1.68, 0.035)
		hood.scale = Vector3(1.0, 0.9, 0.9)
		hood.material_override = _material(robe_color.darkened(0.2))
		parent.add_child(hood)
		parent.add_child(_make_sphere(Vector3(-0.09, 1.57, -0.238), 0.035, face_color))
		parent.add_child(_make_sphere(Vector3(0.09, 1.57, -0.238), 0.035, face_color))

	# The chest sigil is a small focal point rather than a large floating ornament.
	var pendant := _make_sphere(Vector3(0, 1.25, -0.285), 0.07, face_color)
	pendant.scale = Vector3(0.72, 1.0, 0.5)
	parent.add_child(pendant)

func _make_sigil(pos: Vector3, color: Color, size: float, with_light: bool = true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = size * 0.68
	ring_mesh.outer_radius = size
	ring.mesh = ring_mesh
	ring.rotation.x = PI * 0.5
	ring.material_override = _material(color, true)
	root.add_child(ring)
	var crystal := MeshInstance3D.new()
	var crystal_mesh := PrismMesh.new()
	crystal_mesh.size = Vector3(size * 0.6, size * 1.25, size * 0.6)
	crystal.mesh = crystal_mesh
	crystal.material_override = _material(color, true)
	root.add_child(crystal)
	if with_light:
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 1.2
		light.omni_range = size * 5.0
		root.add_child(light)
	return root

func _make_sphere(pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color, true)
	return node

func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.4
	return material

func _on_button_hover() -> void:
	_play(&"ui_hover", -9.0)

func _on_button_click() -> void:
	_play(&"ui_click", -6.0)

func _make_button(label_text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = label_text
	button.mouse_entered.connect(_on_button_hover)
	button.pressed.connect(_on_button_click)
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(0.96, 0.91, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.corner_radius_top_left = 7
	normal.corner_radius_top_right = 7
	normal.corner_radius_bottom_left = 7
	normal.corner_radius_bottom_right = 7
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.16)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.15)
	button.add_theme_stylebox_override("pressed", pressed)
	return button

func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

func _choose_trust_mathias() -> void:
	trust_mathias = true
	story_stage = 1
	dialogue_choice_trust.visible = false
	dialogue_choice_question.visible = false
	dialogue_body.text = "You choose to trust Mathias—for now. He inclines his hood, though his silence suggests there are truths he has not yet earned the right to tell. “Then recover the Dawn, Dusk, and Heart Sigils. We will speak again when the sanctuary opens.”"
	dialogue_hint.text = "Quest started • Recover the three Sigils"
	_save_game()

func _choose_question_mathias() -> void:
	trust_mathias = false
	story_stage = 1
	dialogue_choice_trust.visible = false
	dialogue_choice_question.visible = false
	dialogue_body.text = "“What are you hiding?” you demand. Mathias stiffens. “A mistake made long before you were born—and a name the Council swore never to speak.” He turns toward the failing ward. “If you want the truth, bring me the three Sigils. I will not ask you to trust me. Only to finish what has begun.”"
	dialogue_hint.text = "Quest started • Mathias now knows you doubt him"
	_save_game()

func _face_mathias_for_conversation() -> void:
	# Turn both characters toward one another before the dialogue appears, so the
	# conversation reads as a shared moment instead of two models facing away.
	if player == null or mathias == null or not is_instance_valid(mathias):
		return
	var toward_mathias := mathias.global_position - player.global_position
	toward_mathias.y = 0.0
	if toward_mathias.length_squared() < 0.01:
		return
	var toward_player := -toward_mathias
	var player_yaw := atan2(-toward_mathias.x, -toward_mathias.z)
	var mathias_yaw := atan2(-toward_player.x, -toward_player.z)
	yaw = player_yaw
	var turn_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	turn_tween.tween_property(player, "rotation:y", player_yaw, 0.28)
	turn_tween.parallel().tween_property(mathias, "rotation:y", mathias_yaw, 0.28)

func _show_dialogue(title_text: String, body_text: String, hint_text: String) -> void:
	if dialogue_choice_trust != null:
		dialogue_choice_trust.visible = false
	if dialogue_choice_question != null:
		dialogue_choice_question.visible = false
	dialogue_open = true
	dialogue_title.text = title_text
	dialogue_full_text = body_text
	dialogue_reveal = 0.0
	dialogue_typing = true
	_letter_timer = 0.0
	dialogue_body.text = ""
	dialogue_hint.text = hint_text
	dialogue_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _advance_dialogue() -> void:
	if not dialogue_open:
		return
	# The post-battle conversation offers an explicit trust/doubt choice.
	# E/click should finish the spoken line without hiding the buttons underneath it.
	if story_stage == 0 and enemy_nodes.is_empty() and dialogue_choice_trust.visible:
		dialogue_typing = false
		dialogue_body.text = dialogue_full_text
		dialogue_hint.text = "Choose how you answer Mathias"
		return
	# A single click finishes the line and advances in the same press.
	dialogue_typing = false
	dialogue_body.text = dialogue_full_text
	dialogue_panel.visible = false
	dialogue_open = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if story_stage == 0 and enemy_nodes.is_empty():
		story_stage = 1
		_save_game()
		_show_dialogue("MATHIAS • THE FAILING WARDS", "“You held the line, " + player_name + ". These were not ordinary shades. The ward-stones across the realms are being corrupted from the inside. The Council's old riddles, relic records, and bounty ledgers all point toward the same wound.” Mathias looks toward the sealed sanctuary. “Recover the Dawn, Dusk, and Heart Sigils. Then we can ask the Codex what the Council has forgotten.”", "Find the three Sigils")
		return
	if story_stage == 1 and collected_sigils >= 3:
		story_stage = 2
		_save_game()
		_play_music(&"music_dark_heart", -17.0)
		var revelation := "Mathias admits that he feared the Council would repeat its oldest mistake." if trust_mathias else "Mathias sees that you still doubt him. He gives you one truth anyway: the Council erased a name to keep the Hollow Crown from claiming it."
		_show_dialogue("THE SANCTUARY OPENS", "The three sigils circle the gate and settle into its stonework. The violet sky clears for a heartbeat. " + revelation + " The Realm's Archivists speak of a page that never was, an Archive Wisp, and a crown erased from every record. If this corruption reaches that secret, Gloamwick is only the beginning. The trail leads beyond this valley—and into the Saga of the Hollow Crown.", "Enter the Sigil Sanctuary")
		return
	if story_stage >= 2:
		_play_music(&"music_after_dark", -18.0)
		_show_dialogue("CHAPTER I COMPLETE", "Your Chronicle now carries the first record of the failing wards. The Council's saga continues beyond Gloamwick: forbidden pages, familiars born from memory, rival paths, ancient relics, and the Hollow Crown. Future chapters will build on this journey.", "Return to the Realm")
		return
	_refresh_objective()

func _interact() -> void:
	if dialogue_open:
		_advance_dialogue()
		return
	if player == null:
		return
	if not enemy_nodes.is_empty():
		var nearest_enemy := _nearest_node(enemy_nodes)
		if nearest_enemy != null and player.global_position.distance_to(nearest_enemy.global_position) < 16.0:
			_set_status("The riftbound block your way. Press Q to cast an Arcane Pulse.")
		else:
			_set_status("The square is dangerous. Find Mathias near the broken ward.")
		return

	var item := _nearest_collectible()
	if item != null and _distance_to(item) < 2.6:
		var item_name := str(item.get_meta("item_name", "Item"))
		var item_kind := str(item.get_meta("item_kind", "relic"))
		collectibles.erase(item)
		item.queue_free()
		if not collected_items.has(item_name):
			collected_items.append(item_name)
		_refresh_inventory()
		_save_game()
		_play(&"ui_confirm", -8.0)
		_set_status(("New gear: " if item_kind == "gear" else "Quest item: ") + item_name)
		return

	if archive_wisp != null and is_instance_valid(archive_wisp) and archive_wisp.visible and _distance_to(archive_wisp) < 3.0:
		archive_wisp.visible = false
		lore_discovered = true
		_save_game()
		_show_dialogue("THE ARCHIVE WISP", "A pale blue light gathers around your hand. A memory unfolds: three wardens stood before the Hollow Crown, and one of them begged the Council to erase a name rather than let it be claimed by the Rift. The wisp fades, leaving only the warning: “Do not mistake silence for peace.”", "Lore discovered • Return to the trail")
		return

	if story_stage == 0 and _distance_to(mathias) < 4.0:
		_face_mathias_for_conversation()
		_show_dialogue("MATHIAS • BATTLE MAGE", "“The first wave is gone, but the ward is still bleeding light. I have served the Council for decades, and I have never seen a seal answer to something outside the Realm. Gather the three Sigils. Dawn, Dusk, Heart—remember their names. They are not keys alone; they are promises the Council made.”", "Choose how you answer Mathias")
		dialogue_choice_trust.visible = true
		dialogue_choice_question.visible = true
		return

	if story_stage <= 1:
		var nearest_sigil := _nearest_node(sigil_nodes)
		if nearest_sigil != null and _distance_to(nearest_sigil) < 3.2:
			var sigil_name := str(nearest_sigil.get_meta("sigil_name", "Unknown"))
			nearest_sigil.visible = false
			sigil_nodes.erase(nearest_sigil)
			if not collected_sigil_names.has(sigil_name):
				collected_sigil_names.append(sigil_name)
			collected_sigils = collected_sigil_names.size()
			_set_status(sigil_name + " Sigil recovered • " + str(collected_sigils) + "/3")
			_save_game()
			_refresh_objective()
			if collected_sigils >= 3:
				_show_dialogue("THE THREEFOLD SEAL", "Dawn warms the stone. Dusk turns the air to violet glass. Heart hums like a memory shared by strangers. The three powers recognize one another, and the sanctuary gate begins to open.", "Continue")
			return

	if story_stage >= 2 and _distance_to(sanctuary_gate) < 6.0:
		_show_dialogue("BEYOND GLOAMWICK", "The sanctuary's threshold leads into a wider Realm: wild places shaped by old magic, shifting hollows, sealed archives, and trials recorded by the Council. The road ahead is open. Your story is only beginning.", "Continue")
		return

	if _distance_to(mathias) < 4.0:
		_face_mathias_for_conversation()
		_show_dialogue("MATHIAS", "“The Sigils remember more than we do. Let the Codex guide your next step.”", "Continue")
		return
	_set_status("Nothing answers here. Move closer to Mathias, a Sigil, or the sanctuary gate.")

func _cast_arcane_pulse() -> void:
	if dialogue_open or enemy_nodes.is_empty() or player == null:
		return
	var target := _nearest_node(enemy_nodes)
	if target == null:
		return
	if player.global_position.distance_to(target.global_position) > 18.0:
		_set_status("Too far away. Move closer to the riftbound.")
		return
	_play_music(&"music_reinforcements", -16.0)
	var spell_names := {
		"Ember Mage": "Cinder Lance",
		"Frostweaver": "Glacial Shard",
		"Verdant Warden": "Thornbind",
		"Storm Herald": "Stormcall",
		"Voidcaller": "Rift Rend",
		"Sigilbinder": "Arcane Pulse"
	}
	var damage := 1
	if player_path == "Ember Mage" or player_path == "Voidcaller":
		damage = 2
	var id := target.get_instance_id()
	var remaining := int(enemy_hp.get(id, 2)) - damage
	if remaining <= 0:
		enemy_nodes.erase(target)
		enemy_hp.erase(id)
		target.queue_free()
		_set_status(str(spell_names.get(player_path, "Arcane Pulse")) + " disperses a riftbound shade. " + str(enemy_nodes.size()) + " remain.")
		if enemy_nodes.is_empty():
			battle_cleared = true
			_play_music(&"music_voices_of_mire", -19.0)
			_set_status("The last shade dissolves. Mathias is safe—speak with him using E.")
			_save_game()
	else:
		enemy_hp[id] = remaining
		_set_status(str(spell_names.get(player_path, "Arcane Pulse")) + " strikes the shade. One more hit should break its hold.")
	# Storm Herald magic arcs into a second nearby foe, rewarding the Storm path with crowd control.
	if player_path == "Storm Herald" and not enemy_nodes.is_empty():
		for chained_target in enemy_nodes.duplicate():
			if is_instance_valid(chained_target) and player.global_position.distance_to(chained_target.global_position) <= 8.0:
				var chained_id: int = chained_target.get_instance_id()
				var chained_hp := int(enemy_hp.get(chained_id, 2)) - 1
				if chained_hp <= 0:
					enemy_nodes.erase(chained_target)
					enemy_hp.erase(chained_id)
					chained_target.queue_free()
				else:
					enemy_hp[chained_id] = chained_hp
				_set_status("Stormcall chains lightning through the riftbound!")
				break
	_refresh_objective()

func _nearest_node(nodes: Array[Node3D]) -> Node3D:
	var nearest: Node3D
	var nearest_distance := INF
	for node in nodes:
		if not is_instance_valid(node):
			continue
		var distance := player.global_position.distance_to(node.global_position)
		if distance < nearest_distance:
			nearest = node
			nearest_distance = distance
	return nearest

func _distance_to(node: Node3D) -> float:
	if node == null or not is_instance_valid(node) or player == null:
		return INF
	return player.global_position.distance_to(node.global_position)

func _refresh_objective() -> void:
	if objective_label == null:
		return
	if not enemy_nodes.is_empty():
		objective_label.text = "Protect Mathias: repel the riftbound with Q (" + str(enemy_nodes.size()) + " remain)."
	elif story_stage == 0:
		objective_label.text = "Speak with Mathias near the broken ward. Press E."
	elif story_stage == 1 and collected_sigils < 3:
		objective_label.text = "Recover the Dawn, Dusk, and Heart Sigils (" + str(collected_sigils) + "/3). Press E near a Sigil."
	elif story_stage == 1:
		objective_label.text = "Return to Mathias and learn what the three Sigils have awakened."
	else:
		objective_label.text = "Chapter I complete • The Saga of the Hollow Crown awaits beyond the sanctuary."
	if status_label != null and status_label.text == "":
		status_label.text = player_name + " • " + player_path + " • " + str(collected_sigils) + " Sigils"

func _set_status(message: String) -> void:
	last_message = message
	if status_label != null:
		status_label.text = message

func _load_save() -> void:
	var err := save_data.load(SAVE_PATH)
	has_save = err == OK
	if has_save:
		lore_discovered = bool(save_data.get_value("progress", "lore_discovered", false))
		battle_cleared = bool(save_data.get_value("progress", "battle_cleared", false))
		var saved_sigils = save_data.get_value("progress", "sigil_names", PackedStringArray())
		collected_sigil_names.clear()
		for saved_sigil in saved_sigils:
			collected_sigil_names.append(str(saved_sigil))
		if collected_sigil_names.is_empty() and int(save_data.get_value("progress", "sigils", 0)) > 0:
			var old_count := int(save_data.get_value("progress", "sigils", 0))
			var old_order := ["Dawn", "Dusk", "Heart"]
			for old_index in range(mini(old_count, old_order.size())):
				collected_sigil_names.append(old_order[old_index])
		collected_sigils = collected_sigil_names.size()
		trust_mathias = bool(save_data.get_value("story", "trust_mathias", true))
		player_name = str(save_data.get_value("player", "name", "Apprentice"))
		player_path = str(save_data.get_value("player", "path", "Sigilbinder"))
		story_stage = int(save_data.get_value("progress", "stage", 0))
		collected_sigils = int(save_data.get_value("progress", "sigils", 0))
		appearance.robe = save_data.get_value("appearance", "robe", appearance.robe)
		appearance.accent = save_data.get_value("appearance", "accent", appearance.accent)
		appearance.skin = save_data.get_value("appearance", "skin", appearance.skin)
		appearance.hat = int(save_data.get_value("appearance", "hat", appearance.hat))
		appearance.staff = bool(save_data.get_value("appearance", "staff", appearance.staff))
		_refresh_preview()

func _save_game() -> void:
	save_data.set_value("player", "name", player_name)
	save_data.set_value("player", "path", player_path)
	save_data.set_value("progress", "stage", story_stage)
	save_data.set_value("progress", "sigils", collected_sigil_names.size())
	save_data.set_value("progress", "sigil_names", PackedStringArray(collected_sigil_names))
	save_data.set_value("progress", "battle_cleared", battle_cleared)
	save_data.set_value("progress", "lore_discovered", lore_discovered)
	save_data.set_value("story", "trust_mathias", trust_mathias)
	save_data.set_value("world", "seed", WORLD_SEED)
	save_data.set_value("appearance", "robe", appearance.robe)
	save_data.set_value("appearance", "accent", appearance.accent)
	save_data.set_value("appearance", "skin", appearance.skin)
	save_data.set_value("appearance", "hat", appearance.hat)
	save_data.set_value("appearance", "staff", appearance.staff)
	var err := save_data.save(SAVE_PATH)
	has_save = err == OK
	if continue_button != null:
		continue_button.disabled = not has_save

# ---------------------------------------------------------------------------
# Loading screen, ambient animation and HUD helpers
# ---------------------------------------------------------------------------

func _show_loading() -> void:
	if loading_root == null:
		return
	loading_root.visible = true
	loading_root.modulate.a = 1.0
	loading_bar.value = 0.0
	loading_status.text = "Awakening the wards…"
	var elapsed := 0.0
	while elapsed < 1.25:
		elapsed += get_process_delta_time()
		loading_bar.value = minf(88.0, elapsed / 1.25 * 88.0)
		loading_spinner.pivot_offset = loading_spinner.size * 0.5
		loading_spinner.rotation += 0.16
		await get_tree().process_frame
	loading_status.text = "Raising Gloamwick from the mist…"

func _hide_loading() -> void:
	if loading_root == null:
		return
	loading_bar.value = 100.0
	loading_status.text = "Enter the realm"
	await get_tree().create_timer(0.3).timeout
	var tw := create_tween()
	tw.tween_property(loading_root, "modulate:a", 0.0, 0.5)
	await tw.finished
	loading_root.visible = false
	loading_root.modulate.a = 1.0

## Slow spin + float for sigils, wisps and collectibles, plus a warm flicker for
## every omni light — procedural life for a world with no baked animation.
func _animate_world(delta: float) -> void:
	if spin_nodes.is_empty() and flicker_lights.is_empty():
		return
	_world_time += delta
	for node in spin_nodes:
		if not is_instance_valid(node):
			continue
		node.rotation.y += delta * 0.7
		var base_y: float = node.get_meta("base_y", node.position.y)
		var phase: float = node.get_meta("phase", 0.0)
		node.position.y = base_y + sin(_world_time * 1.6 + phase) * 0.11
	for light in flicker_lights:
		if not is_instance_valid(light):
			continue
		var base_energy: float = light.get_meta("base_energy", 1.0)
		var flicker: float = light.get_meta("flicker_seed", 0.0)
		light.light_energy = base_energy * (0.85 + sin(_world_time * 8.5 + flicker) * 0.11 + sin(_world_time * 23.0 + flicker) * 0.05)

func _register_spin(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_meta("base_y", node.position.y)
	node.set_meta("phase", randf() * TAU)
	spin_nodes.append(node)

func _collect_lights(node: Node) -> void:
	if node is OmniLight3D:
		var light := node as OmniLight3D
		if not light.has_meta("base_energy"):
			light.set_meta("base_energy", light.light_energy)
			light.set_meta("flicker_seed", randf() * 12.0)
			flicker_lights.append(light)
	for child in node.get_children():
		_collect_lights(child)

## A labelled row of colour swatches; picking one calls `on_pick` with the colour.
func _make_swatch_row(parent: Control, title_text: String, colors: Array, on_pick: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = title_text
	title.custom_minimum_size = Vector2(110, 0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.81, 0.69, 0.94))
	row.add_child(title)
	for color in colors:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(34, 34)
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		sb.set_border_width_all(2)
		sb.border_color = Color(1, 1, 1, 0.18)
		swatch.add_theme_stylebox_override("normal", sb)
		swatch.add_theme_stylebox_override("hover", sb)
		swatch.add_theme_stylebox_override("pressed", sb)
		swatch.pressed.connect(func() -> void: on_pick.call(color))
		row.add_child(swatch)
	parent.add_child(row)

## Rebuild the creator's 3D preview from the current appearance, using the same
## rigged human the game uses so the preview matches the final character.
func _refresh_preview() -> void:
	if preview_pivot == null or not is_instance_valid(preview_pivot):
		return
	for child in preview_pivot.get_children():
		preview_pivot.remove_child(child)
		child.queue_free()
	var dummy := CharacterBody3D.new()
	dummy.collision_layer = 0
	dummy.collision_mask = 0
	preview_pivot.add_child(dummy)
	var rig: AnimatedCharacter = AnimatedCharacterScript.new()
	preview_pivot.add_child(rig)
	if rig.setup(dummy):
		rig.use_simple_idle()
		rig.set_tint(appearance.skin)
		_attach_wizard_extras(rig)
	else:
		rig.queue_free()
		preview_pivot.add_child(appearance.build())

## Dress the rigged human with the creator's hat/hood and staff on its bones.
func _attach_wizard_extras(rig: AnimatedCharacter) -> void:
	if appearance.staff:
		var staff_node := appearance.build_staff()
		staff_node.rotation = Vector3(0.0, 0.0, -PI * 0.5)
		staff_node.position = Vector3(0.0, 0.0, 0.0)
		rig.attach_to_bone("B-handProp.R", staff_node)
	match appearance.hat:
		0:
			rig.attach_to_bone("Head", appearance.build_hat(), Vector3(0, 0.18, 0))
		1:
			rig.attach_to_bone("Head", appearance.build_hood(), Vector3(0, 0.13, 0))

func _refresh_player_panel() -> void:
	if hud_root == null:
		return
	var name_line := hud_root.find_child("PlayerNameLine", true, false) as Label
	if name_line != null:
		name_line.text = player_name
	var path_line := hud_root.find_child("PlayerPathLine", true, false) as Label
	if path_line != null:
		path_line.text = "Path of the " + player_path + "  •  Chapter I"
