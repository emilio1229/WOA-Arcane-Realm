extends Node3D

const SAVE_PATH := "user://woa_arcane_realm.cfg"
const WORLD_SEED := 730241
const WALK_SPEED := 5.2
const RUN_SPEED := 8.0
const JUMP_VELOCITY := 6.8
const GRAVITY := 18.0
const PATHS := ["Ember Mage", "Frostweaver", "Verdant Warden", "Storm Herald", "Voidcaller", "Sigilbinder"]

var player: CharacterBody3D
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

func _ready() -> void:
	_build_ui()
	_load_save()
	_show_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if not started or player == null or dialogue_open:
		if player != null:
			player.velocity.x = move_toward(player.velocity.x, 0.0, 22.0 * delta)
			player.velocity.z = move_toward(player.velocity.z, 0.0, 22.0 * delta)
			if not player.is_on_floor():
				player.velocity.y -= GRAVITY * delta
			player.move_and_slide()
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
	player.move_and_slide()
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

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.012, 0.055, 0.96)
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
	columns.add_theme_constant_override("separation", 42)
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

	var form_wrap := CenterContainer.new()
	form_wrap.custom_minimum_size = Vector2(410, 0)
	columns.add_child(form_wrap)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(390, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.032, 0.09, 0.97), Color(0.48, 0.29, 0.67)))
	form_wrap.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var menu_heading := Label.new()
	menu_heading.text = "ENTER THE REALM"
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
	status_label.position = Vector2(20, 100)
	status_label.custom_minimum_size = Vector2(480, 34)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.83, 1.0))
	hud_root.add_child(status_label)

	dialogue_panel = PanelContainer.new()
	dialogue_panel.anchor_left = 0.08
	dialogue_panel.anchor_right = 0.92
	dialogue_panel.anchor_top = 0.68
	dialogue_panel.anchor_bottom = 0.96
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
	dialogue_body.add_theme_font_size_override("font_size", 15)
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
	hud_root.visible = true
	started = true
	_build_world()
	_build_player()
	_refresh_objective()
	if show_intro:
		_show_dialogue("A VOICE BETWEEN THE TREES", "“Awaken, " + player_name + "… Do not fear the dark. It has not found you by accident. You lie beneath the black boughs of Gloamwood, far from any road you remember. The forest has taken your tracks, the night has swallowed the trail, and your mount is nowhere in sight. You carry little but a fading mark of magic and the will to keep moving. Listen. Beyond the mist, someone is fighting—and if the last ward falls, this forest will wake hungry. Follow the violet lights. They will lead you to the truth.”", "Awaken • Follow the violet lights through the forest")
	else:
		_show_dialogue("THE FOREST REMEMBERS", "Your Chronicle stirs again. The voice is quieter now, but the violet lights still lead through the trees toward the broken ward—and the battle beyond the mist.", "Continue toward the distant clash")

func _build_world() -> void:
	for child in get_children():
		if child == ui_layer:
			continue
		child.queue_free()

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.018, 0.008, 0.045)
	sky_material.sky_horizon_color = Color(0.16, 0.055, 0.23)
	sky_material.ground_bottom_color = Color(0.018, 0.012, 0.03)
	sky_material.ground_horizon_color = Color(0.07, 0.035, 0.095)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.44, 0.7)
	environment.ambient_light_energy = 0.8
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.12, 0.055, 0.17)
	environment.fog_density = 0.009
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	_add_box("Gloamwood and Gloamwick Ground", Vector3(0, -0.5, -70), Vector3(180, 1, 260), Color(0.035, 0.045, 0.045), true)
	_add_box("Gloamwick Road", Vector3(0, -0.02, -16), Vector3(6.5, 0.12, 112), Color(0.09, 0.075, 0.085), false)
	# A wooded ridge frames the settlement while leaving the town streets open.
	for i in range(18):
		var z := 25.0 - float(i) * 5.1
		var side_offset := 27.0 + float((i * 7) % 5) * 1.8
		_place_imported_asset("res://OBJ/CommonTree_" + str((i % 5) + 1) + ".obj", Vector3(-side_offset, 0, z), Vector3.ONE * 1.1, float(i) * 0.41)
		_place_imported_asset("res://OBJ/CommonTree_" + str(((i + 2) % 5) + 1) + ".obj", Vector3(side_offset + 2.0, 0, z - 2.2), Vector3.ONE * 1.25, float(i) * -0.33)
	# Broken stones and a forgotten shrine mark the old road into the settlement.
	_add_box("Fallen Blackwood", Vector3(-24.9, 0.55, -8.5), Vector3(3.7, 0.45, 0.55), Color(0.055, 0.03, 0.04), false).rotation.z = -0.22
	_add_box("Mossy Standing Stone", Vector3(23.5, 1.0, -18), Vector3(0.85, 2.0, 0.8), Color(0.11, 0.075, 0.15), false)
	_add_box("Broken Wardstone", Vector3(-8.8, 0.75, -44), Vector3(0.65, 1.5, 0.65), Color(0.18, 0.09, 0.28), false)
	_add_box("Forgotten Shrine", Vector3(10.5, 0.7, -45), Vector3(1.4, 1.4, 1.1), Color(0.09, 0.055, 0.16), false)
	archive_wisp = _make_sigil(Vector3(10.5, 2.0, -45), Color(0.36, 0.86, 0.95), 0.42)
	archive_wisp.name = "Archive Wisp"
	archive_wisp.visible = not lore_discovered
	add_child(archive_wisp)
	_add_box("Sanctuary Gate", Vector3(0, 3.0, -62), Vector3(10, 6, 0.8), Color(0.12, 0.075, 0.19), false)
	sanctuary_gate = _make_sigil(Vector3(0, 2.4, -61.45), Color(0.38, 0.12, 0.75), 2.1)
	sanctuary_gate.name = "Sigil Sanctuary Gate"
	add_child(sanctuary_gate)

	# Beyond the old sanctuary threshold, the forest road opens into Gloamwick.
	_build_gloamwick_town()

	# Violet wisps act as subtle wayfinding lights from the waking place to the clearing.
	for i in range(9):
		var wisp_z := -3.0 - float(i) * 4.0
		var wisp_x := -1.4 if i % 2 == 0 else 1.35
		var wisp := _make_sigil(Vector3(wisp_x, 0.8 + float(i % 3) * 0.35, wisp_z), Color(0.52, 0.27, 0.92), 0.22)
		wisp.name = "Violet Forest Wisp " + str(i + 1)
		add_child(wisp)

	# The forest opens into a ward-clearing where Mathias is already holding the line.
	_add_box("Battle Clearing", Vector3(0, -0.02, -39), Vector3(22, 0.14, 19), Color(0.075, 0.06, 0.085), false)
	mathias = _build_person("Mathias", Vector3(0, 0, -35), Color(0.16, 0.11, 0.28), Color(0.8, 0.72, 0.92), true)
	if not battle_cleared:
		for i in range(3):
			var x := -3.2 + float(i) * 3.2
			var enemy := _build_person("Riftbound " + str(i + 1), Vector3(x, 0, -40.5), Color(0.035, 0.02, 0.07), Color(0.56, 0.18, 0.75), false)
			enemy_nodes.append(enemy)
			enemy_hp[enemy.get_instance_id()] = 2

	var sigil_positions := [Vector3(-8.0, 0.0, -48.0), Vector3(8.0, 0.0, -48.0), Vector3(0.0, 0.0, -54.0)]
	var sigil_names := ["Dawn", "Dusk", "Heart"]
	var sigil_colors := [Color(0.98, 0.66, 0.24), Color(0.52, 0.35, 0.95), Color(0.28, 0.85, 0.72)]
	for i in range(3):
		var shrine := _make_sigil(sigil_positions[i] + Vector3(0, 1.1, 0), sigil_colors[i], 0.75)
		shrine.name = sigil_names[i] + " Sigil"
		shrine.set_meta("sigil_name", sigil_names[i])
		shrine.visible = not collected_sigil_names.has(sigil_names[i])
		sigil_nodes.append(shrine)
		add_child(shrine)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "PlayerWizard"
	player.position = Vector3(0, 0, 12.0)
	player.floor_snap_length = 0.35
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.85
	collision.shape = capsule
	collision.position.y = 0.93
	player.add_child(collision)

	player_visual = Node3D.new()
	player_visual.name = "WizardVisual"
	player.add_child(player_visual)
	var path_colors := {
		"Ember Mage": Color(0.48, 0.12, 0.09),
		"Frostweaver": Color(0.12, 0.3, 0.48),
		"Verdant Warden": Color(0.12, 0.34, 0.2),
		"Storm Herald": Color(0.27, 0.2, 0.52),
		"Voidcaller": Color(0.12, 0.055, 0.2),
		"Sigilbinder": Color(0.22, 0.12, 0.42)
	}
	_add_person_visual(player_visual, path_colors.get(player_path, Color(0.22, 0.12, 0.42)), Color(0.83, 0.75, 0.96), true)
	add_child(player)

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

func _build_gloamwick_town() -> void:
	# Gloamwick is the opening map, not a distant prop cluster: the player enters
	# through the north road, passes the market, and reaches Mathias at the south ward.
	_add_box("Gloamwick North Road", Vector3(0, -0.015, -15), Vector3(7.0, 0.12, 62), Color(0.105, 0.082, 0.095), false)
	_add_box("West Lane", Vector3(-13.0, -0.01, -19), Vector3(3.0, 0.1, 49), Color(0.085, 0.068, 0.08), false)
	_add_box("East Lane", Vector3(13.0, -0.01, -19), Vector3(3.0, 0.1, 49), Color(0.085, 0.068, 0.08), false)
	_add_box("Market Square", Vector3(0, 0.015, -15), Vector3(28, 0.16, 22), Color(0.13, 0.105, 0.13), false)
	_add_box("Square Stone Inlay", Vector3(0, 0.105, -15), Vector3(11, 0.035, 11), Color(0.19, 0.15, 0.2), false)

	# Modeled stone arches frame the north entrance and the damaged ward road.
	_place_imported_asset("res://OBJ/Wall_Arch.obj", Vector3(0.0, 0.0, 13.0), Vector3.ONE * 1.7, 0.0)
	_place_imported_asset("res://OBJ/Wall_Arch.obj", Vector3(0.0, 0.0, -43.0), Vector3.ONE * 1.7, 0.0)
	# The Hollow Lantern is the town's landmark, with a gabled roof, chimney,
	# warm windows, a readable sign, and an open approach from the road.
	_build_house(Vector3(0, 0, -2.5), Color(0.13, 0.065, 0.105))
	_add_box("Hollow Lantern Signboard", Vector3(0, 2.55, -5.18), Vector3(3.4, 0.72, 0.16), Color(0.22, 0.11, 0.31), false)
	_add_box("Inn Sign Rune", Vector3(0, 2.56, -5.29), Vector3(0.34, 0.42, 0.08), Color(0.65, 0.36, 0.95), false)
	_add_box("Inn Chimney", Vector3(2.15, 4.1, -1.5), Vector3(0.65, 1.7, 0.7), Color(0.16, 0.09, 0.12), true)

	# Eight homes form two distinct streets, with small front gardens and lanes.
	var house_colors: Array[Color] = [
		Color(0.13, 0.075, 0.105), Color(0.09, 0.075, 0.13),
		Color(0.12, 0.085, 0.07), Color(0.08, 0.09, 0.13),
		Color(0.11, 0.065, 0.09), Color(0.12, 0.095, 0.065),
		Color(0.095, 0.08, 0.12), Color(0.14, 0.075, 0.075)
	]
	var house_positions: Array[Vector3] = [
		Vector3(-18, 0, -5), Vector3(18, 0, -5),
		Vector3(-18, 0, -17), Vector3(18, 0, -17),
		Vector3(-18, 0, -29), Vector3(18, 0, -29),
		Vector3(-18, 0, -40), Vector3(18, 0, -40)
	]
	for i in range(house_positions.size()):
		_build_house(house_positions[i], house_colors[i])
		var front_lantern_z: float = house_positions[i].z - 2.8
		_place_imported_asset("res://Exports/OBJ/Lantern_Wall.obj", house_positions[i] + Vector3(-2.35, 2.15, front_lantern_z - house_positions[i].z), Vector3.ONE * 0.32, 0.0)

	# The market has actual imported stalls and cargo props rather than empty cubes.
	for i in range(4):
		var stall_x: float = -9.0 + float(i) * 6.0
		_place_imported_asset("res://Exports/OBJ/Stall_Empty.obj", Vector3(stall_x, 0.0, -8.5), Vector3.ONE * 0.9, 0.0)
		_place_imported_asset("res://OBJ/Prop_Crate.obj", Vector3(stall_x + 1.0, 0.0, -6.5), Vector3.ONE * 0.55, float(i) * 0.4)
		if i % 2 == 0:
			_place_imported_asset("res://OBJ/Prop_Wagon.obj", Vector3(stall_x, 0.0, -23.0), Vector3.ONE * 0.7, 1.57)

	# A rune well gives the square a central landmark and a natural meeting point.
	_add_box("Rune Well Foundation", Vector3(0, 0.24, -16.5), Vector3(3.4, 0.48, 3.4), Color(0.16, 0.12, 0.2), true)
	_add_box("Rune Well Inner Pool", Vector3(0, 0.51, -16.5), Vector3(2.0, 0.1, 2.0), Color(0.035, 0.13, 0.18), false)
	var well_rune := _make_sigil(Vector3(0, 1.15, -16.5), Color(0.34, 0.76, 0.98), 0.42)
	well_rune.name = "Gloamwick Rune Well"
	add_child(well_rune)

	# Benches, fences, plants, flowers, mushrooms, stones and trees add scale
	# around the homes without obstructing the streets or combat approach.
	for side in [-1.0, 1.0]:
		for garden_index in range(4):
			var garden_z: float = -3.0 - float(garden_index) * 11.0
			_place_imported_asset("res://OBJ/Prop_WoodenFence_Single.obj", Vector3(side * 22.0, 0.0, garden_z), Vector3.ONE * 0.8, 0.0)
			_place_imported_asset("res://OBJ/Bush_Common_Flowers.obj", Vector3(side * 21.0, 0.0, garden_z - 2.0), Vector3.ONE * 0.55, float(garden_index) * 0.8)
			_place_imported_asset("res://OBJ/Flower_3_Group.obj", Vector3(side * 15.3, 0.0, garden_z - 1.5), Vector3.ONE * 0.5, float(garden_index) * 0.6)
	for i in range(12):
		var tree_side: float = -1.0 if i % 2 == 0 else 1.0
		var tree_z: float = 20.0 - float(i) * 6.2
		var tree_x: float = tree_side * (29.0 + float(i % 3) * 2.5)
		_place_imported_asset("res://OBJ/CommonTree_" + str((i % 5) + 1) + ".obj", Vector3(tree_x, 0.0, tree_z), Vector3.ONE * 1.1, float(i) * 0.53)
	for i in range(8):
		var plant_side: float = -1.0 if i % 2 == 0 else 1.0
		var plant_pos := Vector3(plant_side * (9.0 + float(i % 3)), 0.0, -4.0 - float(i) * 4.4)
		var plant_path: String = "res://OBJ/Bush_Common.obj" if i % 2 == 0 else "res://OBJ/Plant_1_Big.obj"
		_place_imported_asset(plant_path, plant_pos, Vector3.ONE * 0.55, float(i) * 0.61)
	_place_imported_asset("res://OBJ/Mushroom_Common.obj", Vector3(-6.5, 0.0, -35.5), Vector3.ONE * 0.55, 0.0)
	_place_imported_asset("res://OBJ/Mushroom_Laetiporus.obj", Vector3(7.0, 0.0, -37.0), Vector3.ONE * 0.4, 0.0)
	_place_imported_asset("res://OBJ/Rock_Medium_1.obj", Vector3(-9.0, 0.0, -44.5), Vector3.ONE * 0.55, 0.3)
	_place_imported_asset("res://OBJ/Rock_Medium_2.obj", Vector3(9.5, 0.0, -44.0), Vector3.ONE * 0.6, -0.4)

	# Tall rune lamps lead from the market to Mathias and the damaged southern ward.
	for lamp_index in range(7):
		var lamp_z: float = -24.0 - float(lamp_index) * 3.1
		for side in [-1.0, 1.0]:
			var lamp_x: float = float(side) * (6.0 if lamp_index < 4 else 8.0)
			_add_box("Gloamwick Rune Lamp Post", Vector3(lamp_x, 1.65, lamp_z), Vector3(0.16, 3.3, 0.16), Color(0.055, 0.035, 0.065), false)
			var lantern := _make_sigil(Vector3(lamp_x, 3.25, lamp_z), Color(0.98, 0.58, 0.24), 0.2)
			lantern.name = "Gloamwick Lantern"
			add_child(lantern)
	_place_imported_asset("res://OBJ/Prop_Wagon.obj", Vector3(22.0, 0.0, -34.0), Vector3.ONE * 0.85, -0.3)
	_place_imported_asset("res://OBJ/Prop_Crate.obj", Vector3(20.5, 0.0, -33.0), Vector3.ONE * 0.7, 0.2)

func _place_imported_asset(asset_path: String, world_position: Vector3, asset_scale: Vector3, yaw_radians: float = 0.0) -> Node3D:
	# OBJ imports may resolve as a PackedScene or a Mesh depending on importer settings.
	# Handle both so one missing optional import never breaks world generation.
	if not ResourceLoader.exists(asset_path):
		return null
	var resource: Resource = load(asset_path)
	if resource == null:
		push_warning("Optional world asset could not be loaded: " + asset_path)
		return null
	var instance: Node3D
	if resource is PackedScene:
		var spawned: Node = (resource as PackedScene).instantiate()
		if spawned is Node3D:
			instance = spawned as Node3D
		else:
			spawned.free()
			return null
	elif resource is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = resource as Mesh
		instance = mesh_instance
	else:
		push_warning("Unsupported imported world asset type: " + asset_path)
		return null
	instance.name = asset_path.get_file().get_basename()
	instance.position = world_position
	instance.scale = asset_scale
	instance.rotation.y = yaw_radians
	add_child(instance)
	return instance

func _build_house(pos: Vector3, color: Color) -> void:
	# Low-fantasy timber-and-plaster home with a pitched roof, recessed doorway,
	# glowing leaded windows, and chimney; collision stays on the solid walls.
	_add_box("Gloamwick Plaster House", pos + Vector3(0, 1.55, 0), Vector3(6.0, 3.1, 5.0), color, true)
	_add_box("House Timber Beam", pos + Vector3(0, 2.75, -2.54), Vector3(5.8, 0.18, 0.12), Color(0.07, 0.035, 0.04), false)
	_add_box("House Door", pos + Vector3(0, 0.92, -2.58), Vector3(1.0, 1.84, 0.14), Color(0.045, 0.025, 0.04), false)
	_add_box("Door Handle", pos + Vector3(0.32, 0.95, -2.68), Vector3(0.08, 0.08, 0.05), Color(0.75, 0.48, 0.19), false)
	for side in [-1.0, 1.0]:
		var front_window_x: float = float(side) * 1.72
		_add_box("House Window Frame", pos + Vector3(front_window_x, 1.9, -2.59), Vector3(0.95, 1.05, 0.12), Color(0.045, 0.025, 0.055), false)
		_add_box("House Warm Window", pos + Vector3(front_window_x, 1.9, -2.67), Vector3(0.7, 0.8, 0.06), Color(0.95, 0.48, 0.19), false)
		_add_box("House Window Mullion", pos + Vector3(front_window_x, 1.9, -2.72), Vector3(0.08, 0.82, 0.04), Color(0.12, 0.06, 0.07), false)
		# Side doors and windows face the narrow lanes between each row of homes.
		var side_door: Node3D = _add_box("House Side Door", pos + Vector3(float(side) * 3.06, 0.92, 0.0), Vector3(0.14, 1.84, 1.0), Color(0.045, 0.025, 0.04), false)
		side_door.rotation.y = PI * 0.5
		_add_box("House Side Window Frame", pos + Vector3(float(side) * 3.06, 1.95, 1.55), Vector3(0.12, 0.92, 0.8), Color(0.045, 0.025, 0.055), false)
		_add_box("House Side Warm Window", pos + Vector3(float(side) * 3.13, 1.95, 1.55), Vector3(0.06, 0.68, 0.56), Color(0.95, 0.48, 0.19), false)
		_add_box("House Side Window Frame", pos + Vector3(float(side) * 3.06, 1.95, -1.55), Vector3(0.12, 0.92, 0.8), Color(0.045, 0.025, 0.055), false)
		_add_box("House Side Warm Window", pos + Vector3(float(side) * 3.13, 1.95, -1.55), Vector3(0.06, 0.68, 0.56), Color(0.95, 0.48, 0.19), false)
	# Two sloped roof planes create a visible gable instead of a flat slab.
	var roof_left := _add_box("House Pitched Roof Left", pos + Vector3(-1.55, 3.45, 0), Vector3(3.55, 0.28, 5.8), Color(0.055, 0.028, 0.075), false)
	roof_left.rotation.z = -0.48
	var roof_right := _add_box("House Pitched Roof Right", pos + Vector3(1.55, 3.45, 0), Vector3(3.55, 0.28, 5.8), Color(0.075, 0.035, 0.065), false)
	roof_right.rotation.z = 0.48
	_add_box("House Ridge Beam", pos + Vector3(0, 4.18, 0), Vector3(0.22, 0.22, 6.0), Color(0.12, 0.055, 0.07), false)
	_add_box("House Chimney", pos + Vector3(2.0, 4.05, 1.0), Vector3(0.55, 1.2, 0.55), Color(0.16, 0.075, 0.095), true)
	_place_imported_asset("res://OBJ/Prop_Vine1.obj", pos + Vector3(-2.7, 1.8, -2.62), Vector3.ONE * 0.55, 0.0)

func _build_tree(pos: Vector3, height: float) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.42
	trunk_mesh.height = height
	trunk.mesh = trunk_mesh
	trunk.position = pos + Vector3(0, height * 0.5, 0)
	trunk.material_override = _material(Color(0.065, 0.032, 0.04))
	add_child(trunk)

	# Angular boughs break up the old lollipop-tree silhouette.
	for branch_index in range(3):
		var branch := MeshInstance3D.new()
		var branch_mesh := CylinderMesh.new()
		branch_mesh.top_radius = 0.055
		branch_mesh.bottom_radius = 0.13
		branch_mesh.height = 2.1
		branch.mesh = branch_mesh
		branch.position = pos + Vector3(0, height * (0.52 + float(branch_index) * 0.12), 0)
		branch.rotation_degrees = Vector3(0, float(branch_index) * 67.0, -42.0 + float(branch_index) * 19.0)
		branch.material_override = _material(Color(0.055, 0.027, 0.04))
		add_child(branch)

	for canopy_index in range(4):
		var crown := MeshInstance3D.new()
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 1.35 if canopy_index == 0 else 1.05
		crown_mesh.height = crown_mesh.radius * 1.9
		crown.mesh = crown_mesh
		crown.position = pos + Vector3(
			sin(float(canopy_index) * 1.8) * 0.95,
			height + 0.2 + float(canopy_index % 2) * 0.9,
			cos(float(canopy_index) * 1.7) * 0.8
		)
		crown.scale = Vector3(1.0, 1.25, 0.9)
		crown.material_override = _material(Color(0.022 + float(canopy_index) * 0.004, 0.045, 0.038))
		add_child(crown)

	# Tiny bioluminescent mushrooms and spores give the ground depth cues.
	for spore_index in range(2):
		var spore := _make_sphere(pos + Vector3(-0.42 + float(spore_index) * 0.84, 0.16, 0.25), 0.09, Color(0.36, 0.13, 0.62))
		spore.scale = Vector3(1.0, 0.65, 1.0)
		add_child(spore)

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

func _make_sigil(pos: Vector3, color: Color, size: float) -> Node3D:
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
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = size * 5.0
	root.add_child(light)
	return root

func _add_box(object_name: String, pos: Vector3, size: Vector3, color: Color, collision: bool) -> Node3D:
	var root: Node3D
	if collision:
		root = StaticBody3D.new()
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		root.add_child(shape_node)
	else:
		root = Node3D.new()
	root.name = object_name
	root.position = pos
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = _material(color)
	root.add_child(mesh_node)
	add_child(root)
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

func _make_button(label_text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = label_text
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

func _show_dialogue(title_text: String, body_text: String, hint_text: String) -> void:
	if dialogue_choice_trust != null:
		dialogue_choice_trust.visible = false
	if dialogue_choice_question != null:
		dialogue_choice_question.visible = false
	dialogue_open = true
	dialogue_title.text = title_text
	dialogue_body.text = body_text
	dialogue_hint.text = hint_text
	dialogue_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _advance_dialogue() -> void:
	if not dialogue_open:
		return
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
		var revelation := "Mathias admits that he feared the Council would repeat its oldest mistake." if trust_mathias else "Mathias sees that you still doubt him. He gives you one truth anyway: the Council erased a name to keep the Hollow Crown from claiming it."
		_show_dialogue("THE SANCTUARY OPENS", "The three sigils circle the gate and settle into its stonework. The violet sky clears for a heartbeat. " + revelation + " The Realm's Archivists speak of a page that never was, an Archive Wisp, and a crown erased from every record. If this corruption reaches that secret, Gloamwick is only the beginning. The trail leads beyond this valley—and into the Saga of the Hollow Crown.", "Enter the Sigil Sanctuary")
		return
	if story_stage >= 2:
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

	if archive_wisp != null and is_instance_valid(archive_wisp) and archive_wisp.visible and _distance_to(archive_wisp) < 3.0:
		archive_wisp.visible = false
		lore_discovered = true
		_save_game()
		_show_dialogue("THE ARCHIVE WISP", "A pale blue light gathers around your hand. A memory unfolds: three wardens stood before the Hollow Crown, and one of them begged the Council to erase a name rather than let it be claimed by the Rift. The wisp fades, leaving only the warning: “Do not mistake silence for peace.”", "Lore discovered • Return to the trail")
		return

	if story_stage == 0 and _distance_to(mathias) < 4.0:
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
	var err := save_data.save(SAVE_PATH)
	has_save = err == OK
	if continue_button != null:
		continue_button.disabled = not has_save
