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
var dialogue_choices_box: VBoxContainer
var dialogue_continue_button: Button
var path_note_label: Label
var pending_choice_context := ""
var mathias_stance := "unspoken"
var warden_response := "unasked"
var warden_consulted := false
var collected_sigil_names: Array[String] = []
var objective_label: Label
var status_label: Label
var name_input: LineEdit
var path_select: OptionButton
var continue_button: Button
var player_name := "Apprentice"
var player_path := "Sigilbinder"
var yaw := 0.0
var pitch := -0.16
var started := false
var dialogue_open := false
var story_stage := 0
var collected_sigils := 0
var sigil_nodes: Array[Node3D] = []
var enemy_nodes: Array[Node3D] = []
var enemy_hp: Dictionary = {}
var mathias: Node3D
var whispering_warden: Node3D
var sanctuary_gate: Node3D
var last_message := ""
var save_data := ConfigFile.new()
var has_save := false
var _model_scene_cache: Dictionary = {}
var _model_file_index: Dictionary = {}
var _model_index_ready := false

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

func _unhandled_input(event: InputEvent) -> void:
    if not started:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not dialogue_open:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not dialogue_open:
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
    path_select.item_selected.connect(_update_path_note)
    _update_path_note(path_select.selected)

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

    dialogue_choices_box = VBoxContainer.new()
    dialogue_choices_box.add_theme_constant_override("separation", 6)
    dialogue_choices_box.visible = false
    dialogue_layout.add_child(dialogue_choices_box)

    dialogue_hint = Label.new()
    dialogue_hint.text = "Press E or select Continue"
    dialogue_hint.add_theme_font_size_override("font_size", 12)
    dialogue_hint.add_theme_color_override("font_color", Color(0.72, 0.65, 0.8))
    dialogue_layout.add_child(dialogue_hint)

    dialogue_continue_button = _make_button("CONTINUE", Color(0.31, 0.13, 0.48))
    dialogue_continue_button.pressed.connect(_advance_dialogue)
    dialogue_layout.add_child(dialogue_continue_button)

func _update_path_note(_index: int) -> void:
    if path_note_label == null or path_select == null:
        return
    var path_name := PATHS[path_select.selected] if path_select.selected >= 0 else "Sigilbinder"
    match path_name:
        "Ember Mage":
            path_note_label.text = "Ember Mage • Bold flame magic. Your instinct is to act before fear can settle."
        "Frostweaver":
            path_note_label.text = "Frostweaver • Patient control magic. You look for the pattern beneath the chaos."
        "Verdant Warden":
            path_note_label.text = "Verdant Warden • Life and root magic. You listen before you strike."
        "Storm Herald":
            path_note_label.text = "Storm Herald • Swift storm magic. You meet danger head-on and adapt quickly."
        "Voidcaller":
            path_note_label.text = "Voidcaller • Rift-sense and shadow magic. You are willing to question what others fear."
        _:
            path_note_label.text = "Sigilbinder • Ancient runes and wardcraft. You seek the connections others overlook."

func _path_intro() -> String:
    match player_path:
        "Ember Mage":
            return "A coal-bright warmth stirs in your palm, answering the old name of the Ember Mage."
        "Frostweaver":
            return "Frost traces a quiet sigil across your fingers; the Frostweaver's patience wakes with you."
        "Verdant Warden":
            return "A green thread of life curls around your wrist, and the roots beneath you seem to listen."
        "Storm Herald":
            return "A tiny storm crackles beneath your skin, as if the sky has been waiting for your first breath."
        "Voidcaller":
            return "The shadows lean toward you—not in threat, but recognition—and a cold rift-light answers your pulse."
        _:
            return "A ring of faint runes circles your palm, each mark searching for the others it has lost."

func _show_menu() -> void:
    menu_root.visible = true
    hud_root.visible = false
    if has_save:
        name_input.text = player_name
        var saved_path_index := PATHS.find(player_path)
        if saved_path_index >= 0:
            path_select.select(saved_path_index)
            _update_path_note(saved_path_index)
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
    mathias_stance = "unspoken"
    warden_response = "unasked"
    warden_consulted = false
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
    menu_root.visible = false
    hud_root.visible = true
    started = true
    _build_world()
    _build_player()
    _refresh_objective()
    if show_intro:
        _show_dialogue("A VOICE BETWEEN THE TREES", "“Awaken, " + player_name + "… " + _path_intro() + " You lie beneath the black boughs of Gloamwood, far from any road you remember. The forest has taken your tracks, the night has swallowed the trail, and your mount is nowhere in sight. Beyond the mist, someone is fighting—and if the last ward falls, this forest will wake hungry. Follow the violet lights. They will lead you to the truth.”", "Awaken • Follow the violet lights through the forest")
    else:
        _show_dialogue("THE FOREST REMEMBERS", "Your Chronicle stirs again. The voice is quieter now, but the violet lights still lead through the trees toward the broken ward—and the battle beyond the mist.", "Continue toward the distant clash")

func _build_world() -> void:
    # Rebuilds can happen when loading a saved Chronicle; clear references to the old world first.
    sigil_nodes.clear()
    enemy_nodes.clear()
    enemy_hp.clear()
    mathias = null
    whispering_warden = null
    sanctuary_gate = null
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

    _add_box("Gloamwood Floor", Vector3(0, -0.5, -20), Vector3(100, 1, 150), Color(0.035, 0.045, 0.045), true)
    _add_box("Mossy Trail", Vector3(0, -0.02, -20), Vector3(5.5, 0.12, 112), Color(0.09, 0.075, 0.085), false)
    # Dense, staggered trunks frame a winding forest path without blocking the playable trail.
    for i in range(18):
        var z := 12.0 - float(i) * 4.8
        var side_offset := 7.2 + float((i * 7) % 5) * 1.4
        _build_tree(Vector3(-side_offset, 0, z), 5.0 + float(i % 4) * 0.9)
        _build_tree(Vector3(side_offset + 1.0, 0, z - 2.2), 5.8 + float((i + 2) % 4) * 0.8)
    # Fallen timber, standing stones and luminous spores establish a readable trail.
    _add_box("Fallen Blackwood", Vector3(-4.9, 0.55, -8.5), Vector3(3.7, 0.45, 0.55), Color(0.055, 0.03, 0.04), false).rotation.z = -0.22
    _add_box("Mossy Standing Stone", Vector3(4.5, 1.0, -18), Vector3(0.85, 2.0, 0.8), Color(0.11, 0.075, 0.15), false)
    _add_box("Broken Wardstone", Vector3(-2.8, 0.75, -28), Vector3(0.65, 1.5, 0.65), Color(0.18, 0.09, 0.28), false)
    _add_box("Sanctuary Gate", Vector3(0, 3.0, -62), Vector3(10, 6, 0.8), Color(0.12, 0.075, 0.19), false)
    sanctuary_gate = _make_sigil(Vector3(0, 2.4, -61.45), Color(0.38, 0.12, 0.75), 2.1)
    sanctuary_gate.name = "Sigil Sanctuary Gate"
    add_child(sanctuary_gate)

    # Imported Tripo landmarks make the opening path feel connected to the wider Realm.
    # Procedural scenery remains in place if any optional model cannot be imported.
    _add_imported_landmark("ruins", "Ancient Ruin Sentinel", Vector3(-6.8, 0.0, -31.0), 0.65)
    _add_imported_landmark("tower", "The Distant Wizard Tower", Vector3(14.0, 0.0, -65.0), 0.55)
    whispering_warden = _add_imported_landmark("spirit", "The Whispering Warden", Vector3(7.5, 0.0, -28.0), 0.55)

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
    for i in range(3):
        var x := -3.2 + float(i) * 3.2
        var enemy := _build_person("Riftbound " + str(i + 1), Vector3(x, 0, -40.5), Color(0.035, 0.02, 0.07), Color(0.56, 0.18, 0.75), false)
        enemy_nodes.append(enemy)
        enemy_hp[enemy.get_instance_id()] = 1

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
    var player_model := _instantiate_model("player")
    if player_model != null:
        player_visual.add_child(player_model)
        _play_model_idle(player_model)
    else:
        _add_person_visual(player_visual, Color(0.22, 0.12, 0.42), Color(0.83, 0.75, 0.96), true)
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

func _add_imported_landmark(role: String, landmark_name: String, pos: Vector3, model_scale: float) -> Node3D:
    var model := _instantiate_model(role)
    if model == null:
        return null
    model.name = landmark_name
    model.position = pos
    model.scale = Vector3.ONE * model_scale
    _play_model_idle(model)
    add_child(model)
    return model

func _build_house(pos: Vector3, color: Color) -> void:
    _add_box("Gloamwick House", pos + Vector3(0, 1.6, 0), Vector3(6, 3.2, 5), color, true)
    _add_box("House Roof", pos + Vector3(0, 3.55, 0), Vector3(6.8, 0.55, 5.8), Color(0.07, 0.035, 0.09), false)
    _add_box("House Door", pos + Vector3(0, 0.9, -2.55), Vector3(1.0, 1.8, 0.12), Color(0.08, 0.035, 0.08), false)

func _build_tree(pos: Vector3, height: float) -> void:
    var imported_tree := _instantiate_model("tree")
    if imported_tree != null:
        imported_tree.name = "Tripo Forest Tree"
        imported_tree.position = pos
        var target_height := maxf(height, 1.0)
        imported_tree.scale = Vector3.ONE * (target_height / 5.0)
        add_child(imported_tree)
        return

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
    var role := "mathias" if person_name.to_lower().contains("mathias") else ("riftbound" if person_name.to_lower().contains("riftbound") else "player")
    var imported_model := _instantiate_model(role)
    if imported_model != null:
        person.add_child(imported_model)
        _play_model_idle(imported_model)
    else:
        _add_person_visual(person, robe_color, glow_color, is_mage)
    add_child(person)
    return person

# Put Tripo exports anywhere under res://; filename keywords determine their world role.
# Examples: player_wizard.glb, mathias.glb, riftbound_shade.glb, forest_tree.glb.
func _instantiate_model(role: String) -> Node3D:
    var scene := _get_model_scene(role)
    if scene == null:
        return null
    var instance := scene.instantiate()
    if instance is Node3D:
        return instance as Node3D
    instance.free()
    return null

func _get_model_scene(role: String) -> PackedScene:
    if not _model_scene_cache.has(role):
        _build_model_file_index()
        # Prefer exact, intentional assignments before trying generic filename keywords.
        # This prevents "wizard" from accidentally selecting the tower for the player.
        var preferred_names: Array[String] = []
        match role:
            "player":
                preferred_names = ["fantasy_wizard_3d_model", "wizard_robe_3d_model", "player_wizard", "wizard", "mage", "hero", "character"]
            "mathias":
                preferred_names = ["wizard_robe_3d_model", "battle_mage", "mathias", "fantasy_wizard_3d_model"]
            "riftbound":
                preferred_names = ["shadow_beast_3d_model", "haunted_forest_spirit_3d_model", "dark_fantasy_boss_3d_model", "riftbound", "shade", "enemy", "creature"]
            "tree":
                preferred_names = ["forest_tree", "blackwood", "tree"]
            "ruins":
                preferred_names = ["ancient_ruin_stones_3d_model", "ancient_ruin", "ruin"]
            "tower":
                preferred_names = ["wizard_tower_3d_model", "wizard_tower", "tower"]
            "spirit":
                preferred_names = ["haunted_forest_spirit_3d_model", "forest_spirit", "spirit"]
            "guardian":
                preferred_names = ["dark_fantasy_boss_3d_model", "guardian", "boss"]

        var selected_path := ""
        for candidate in preferred_names:
            if _model_file_index.has(candidate):
                selected_path = str(_model_file_index[candidate])
                break

        if selected_path.is_empty():
            for candidate in preferred_names:
                for file_key in _model_file_index.keys():
                    if str(file_key).contains(candidate):
                        selected_path = str(_model_file_index[file_key])
                        break
                if not selected_path.is_empty():
                    break

        if selected_path.is_empty():
            _model_scene_cache[role] = null
        else:
            _model_scene_cache[role] = load(selected_path) as PackedScene
    return _model_scene_cache[role] as PackedScene

func _build_model_file_index() -> void:
    if _model_index_ready:
        return
    _model_index_ready = true
    _scan_model_directory("res://")

func _scan_model_directory(directory_path: String) -> void:
    var directory := DirAccess.open(directory_path)
    if directory == null:
        return
    directory.list_dir_begin()
    var entry := directory.get_next()
    while not entry.is_empty():
        if entry.begins_with("."):
            entry = directory.get_next()
            continue
        var full_path := directory_path.path_join(entry)
        if directory.current_is_dir():
            if entry != "addons" and entry != "web" and entry != "export":
                _scan_model_directory(full_path)
        else:
            var extension := entry.get_extension().to_lower()
            if extension in ["glb", "gltf", "fbx"]:
                _model_file_index[entry.get_basename().to_lower()] = full_path
        entry = directory.get_next()
    directory.list_dir_end()

func _play_model_idle(root: Node) -> void:
    if root is AnimationPlayer:
        var animation_player := root as AnimationPlayer
        var names := animation_player.get_animation_list()
        for candidate in ["idle", "idle_loop", "breathing", "stand", "standing"]:
            for animation_name in names:
                if str(animation_name).to_lower().contains(candidate):
                    animation_player.play(animation_name)
                    return
        if not names.is_empty():
            animation_player.play(names[0])
    for child in root.get_children():
        _play_model_idle(child)

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

func _show_dialogue(title_text: String, body_text: String, hint_text: String) -> void:
    dialogue_open = true
    dialogue_title.text = title_text
    dialogue_body.text = body_text
    dialogue_hint.text = hint_text
    dialogue_choices_box.visible = false
    for child in dialogue_choices_box.get_children():
        child.queue_free()
    dialogue_continue_button.visible = true
    dialogue_panel.anchor_top = 0.68
    dialogue_panel.visible = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _show_dialogue_choices(title_text: String, body_text: String, hint_text: String, context: String, choices: Array[Dictionary]) -> void:
    _show_dialogue(title_text, body_text, hint_text)
    dialogue_panel.anchor_top = 0.54
    pending_choice_context = context
    dialogue_choices_box.visible = true
    dialogue_continue_button.visible = false
    for choice in choices:
        var choice_button := _make_button(str(choice.get("label", "Choose")), Color(0.22, 0.12, 0.34))
        choice_button.custom_minimum_size.y = 38
        choice_button.add_theme_font_size_override("font_size", 14)
        choice_button.pressed.connect(_choose_dialogue.bind(str(choice.get("id", ""))))
        dialogue_choices_box.add_child(choice_button)

func _choose_dialogue(choice_id: String) -> void:
    if not dialogue_open:
        return
    if pending_choice_context == "mathias":
        mathias_stance = choice_id
        story_stage = max(story_stage, 1)
        var mathias_response := ""
        match choice_id:
            "compassion":
                mathias_response = "Mathias studies you, then gives a tired nod. “Good. Power is easy to admire. The choice to stand beside someone when the cost is unknown—that tells me more.” He gestures toward the broken ward. “The Warden nearby remembers the old vows. Hear its warning before you touch the three Sigils.”"
            "suspicion":
                mathias_response = "Mathias' jaw tightens. “Fair. I have withheld too much, and I won't ask you to trust a stranger. The Warden beside the broken ward remembers what my Council records do not. Question it—and question me again when you return.”"
            "duty":
                mathias_response = "Mathias turns back to the wounded ward. “Then we understand each other. Keep people alive first; explanations can follow. The Warden nearby remembers the vows behind the seals. Speak with it, then recover Dawn, Dusk, and Heart.”"
            _:
                mathias_response = "Mathias points toward the broken ward and the waiting Sigils."
        _save_game()
        _refresh_objective()
        _show_dialogue("MATHIAS • THE FIRST VOW", mathias_response + " Dawn, Dusk, and Heart are not trophies. Each holds one part of the promise that keeps this valley whole.", "Quest updated • Seek the Whispering Warden")
    elif pending_choice_context == "warden":
        warden_response = choice_id
        warden_consulted = true
        var warden_answer_text := ""
        match choice_id:
            "dawn":
                warden_answer_text = "“Dawn is not hope,” the Warden whispers. “It is the courage to begin after hope has failed. Find it where the first light touches broken stone.” A pale root curls toward the sanctuary trail."
            "fourth":
                warden_answer_text = "The Warden's light dims. “Three vows were spoken. A fourth was cut from the telling—not broken, not kept, but removed. Ask who benefits when a name cannot be remembered.”"
            "mathias":
                warden_answer_text = "“Trust is a bridge, not a blindfold,” says the Warden. “Let Mathias guide your steps, but let the stones judge his words. The Sigils remember what even loyal hearts forget.”"
            _:
                warden_answer_text = "“Listen to the old stones. They will remember for you.”"
        _save_game()
        _refresh_objective()
        _show_dialogue("THE WARDEN'S ANSWER", warden_answer_text + " “Now you may approach the three Sigils. Dawn, Dusk, and Heart must be gathered together—or the gate will remain a wound pretending to be a door.”", "Quest updated • Recover the three Sigils")
    pending_choice_context = ""

func _advance_dialogue() -> void:
    if not dialogue_open or dialogue_choices_box.visible:
        return
    dialogue_panel.visible = false
    dialogue_open = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if story_stage == 0 and enemy_nodes.is_empty() and dialogue_title.text == "MATHIAS • BATTLE MAGE":
        story_stage = 1
        _save_game()
        _show_dialogue("MATHIAS • THE FAILING WARDS", "“You held the line, " + player_name + ". These were not ordinary shades. The ward-stones across the realms are being corrupted from the inside. The Council's old riddles, relic records, and bounty ledgers all point toward the same wound.” Mathias looks toward the sealed sanctuary. “Recover the Dawn, Dusk, and Heart Sigils. Then we can ask the Codex what the Council has forgotten.”", "Find the three Sigils")
        return
    if story_stage == 1 and collected_sigils >= 3:
        story_stage = 2
        _save_game()
        _show_dialogue("THE SANCTUARY OPENS", "The three sigils circle the gate and settle into its stonework. The violet sky clears for a heartbeat. Mathias lowers his voice: “The Realm's Archivists speak of a page that never was, an Archive Wisp, and a crown erased from every record. If this corruption reaches that secret, Gloamwick is only the beginning.” The trail leads beyond this valley—and into the Saga of the Hollow Crown.", "Enter the Sigil Sanctuary")
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

    if story_stage == 0 and _distance_to(mathias) < 4.0:
        _show_dialogue_choices("MATHIAS • BATTLE MAGE", "The last riftbound shade dissolves into violet sparks. Mathias lowers his staff, but keeps his eyes on the broken ward. “You could have fled. You didn't. Before I ask you to risk more, tell me what brought you here.”", "Your answer will shape Mathias’ trust", "mathias", [
            {"id": "compassion", "label": "“No one should have to face that alone.”"},
            {"id": "suspicion", "label": "“You are hiding something. Start explaining.”"},
            {"id": "duty", "label": "“The ward was failing. That was reason enough.”"}
        ])
        return

    if whispering_warden != null and _distance_to(whispering_warden) < 3.8:
        _show_dialogue_choices("THE WHISPERING WARDEN", "The Warden's bark shifts like a face seen through rain. “Mathias knows the names of the three vows. I remember the silence around them. Ask, little spark—but choose what you wish to carry away.”", "Your question will be recorded in the Chronicle", "warden", [
            {"id": "dawn", "label": "“What does Dawn truly ask of me?”"},
            {"id": "fourth", "label": "“Tell me about the thing erased from the vows.”"},
            {"id": "mathias", "label": "“Can Mathias be trusted?”"}
        ])
        return

    if story_stage <= 1:
        var nearest_sigil := _nearest_node(sigil_nodes)
        if nearest_sigil != null and _distance_to(nearest_sigil) < 3.2:
            if not warden_consulted:
                _set_status("The Sigils remain veiled. Seek the Whispering Warden beside the broken ward first.")
                return
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
    if dialogue_open or enemy_nodes.is_empty():
        return
    var target := _nearest_node(enemy_nodes)
    if target == null:
        return
    if player.global_position.distance_to(target.global_position) > 18.0:
        _set_status("Too far away. Move closer to the riftbound.")
        return
    var id := target.get_instance_id()
    var remaining := int(enemy_hp.get(id, 1)) - 1
    if remaining <= 0:
        enemy_nodes.erase(target)
        enemy_hp.erase(id)
        target.queue_free()
        _set_status("Arcane Pulse disperses a riftbound shade. " + str(enemy_nodes.size()) + " remain.")
        if enemy_nodes.is_empty():
            _set_status("The last shade dissolves. Mathias is safe—speak with him using E.")
            _save_game()
    else:
        enemy_hp[id] = remaining
        _set_status("The shade recoils from the pulse.")
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
    elif story_stage == 1 and not warden_consulted:
        objective_label.text = "Speak with the Whispering Warden by the broken ward. Learn why the three Sigils must be gathered."
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
        player_name = str(save_data.get_value("player", "name", "Apprentice"))
        player_path = str(save_data.get_value("player", "path", "Sigilbinder"))
        story_stage = int(save_data.get_value("progress", "stage", 0))
        collected_sigils = int(save_data.get_value("progress", "sigils", 0))
        collected_sigil_names.clear()
        var saved_names = save_data.get_value("progress", "sigil_names", [])
        for saved_name in saved_names:
            collected_sigil_names.append(str(saved_name))
        if collected_sigil_names.is_empty() and collected_sigils > 0:
            var legacy_names := ["Dawn", "Dusk", "Heart"]
            for legacy_index in range(mini(collected_sigils, legacy_names.size())):
                collected_sigil_names.append(legacy_names[legacy_index])
        mathias_stance = str(save_data.get_value("story", "mathias_stance", "unspoken"))
        warden_response = str(save_data.get_value("story", "warden_response", "unasked"))
        warden_consulted = bool(save_data.get_value("story", "warden_consulted", false))

func _save_game() -> void:
    save_data.set_value("player", "name", player_name)
    save_data.set_value("player", "path", player_path)
    save_data.set_value("progress", "stage", story_stage)
    save_data.set_value("progress", "sigils", collected_sigils)
    save_data.set_value("progress", "sigil_names", collected_sigil_names)
    save_data.set_value("story", "mathias_stance", mathias_stance)
    save_data.set_value("story", "warden_response", warden_response)
    save_data.set_value("story", "warden_consulted", warden_consulted)
    save_data.set_value("world", "seed", WORLD_SEED)
    var err := save_data.save(SAVE_PATH)
    has_save = err == OK
    if continue_button != null:
        continue_button.disabled = not has_save
