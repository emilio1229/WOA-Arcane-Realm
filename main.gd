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

func _unhandled_input(event: InputEvent) -> void:
    if not started:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not dialogue_open:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not dialogue_open:
        yaw -= event.relative.x * 0.0025
        pitch = clampf(pitch - event.relative.y * 0.0018, -0.42, 0.28)
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

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_root.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(540.0, 0.0)
    panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.035, 0.12, 0.98), Color(0.58, 0.32, 0.92)))
    center.add_child(panel)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 13)
    panel.add_child(layout)

    var title := Label.new()
    title.text = "WOA: ARCANE REALM"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 34)
    title.add_theme_color_override("font_color", Color(0.91, 0.78, 1.0))
    layout.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Wizards, Warlocks & Witches"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 16)
    subtitle.add_theme_color_override("font_color", Color(0.77, 0.65, 0.9))
    layout.add_child(subtitle)

    layout.add_child(HSeparator.new())

    var intro := Label.new()
    intro.text = "A living chapter of the Realm. Your deeds become history; every Sigil remembers."
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intro.add_theme_color_override("font_color", Color(0.83, 0.8, 0.9))
    layout.add_child(intro)

    var name_label := Label.new()
    name_label.text = "YOUR WIZARD'S NAME"
    name_label.add_theme_font_size_override("font_size", 13)
    layout.add_child(name_label)

    name_input = LineEdit.new()
    name_input.placeholder_text = "Enter your name..."
    name_input.text = player_name if player_name != "Apprentice" else ""
    name_input.custom_minimum_size = Vector2(0, 42)
    name_input.max_length = 24
    name_input.add_theme_font_size_override("font_size", 17)
    layout.add_child(name_input)

    var path_label := Label.new()
    path_label.text = "CHOOSE YOUR ARCANE PATH"
    path_label.add_theme_font_size_override("font_size", 13)
    layout.add_child(path_label)

    path_select = OptionButton.new()
    path_select.custom_minimum_size = Vector2(0, 42)
    for path_name in PATHS:
        path_select.add_item(path_name)
    path_select.select(5)
    path_select.add_theme_font_size_override("font_size", 16)
    layout.add_child(path_select)

    var begin_button := _make_button("BEGIN YOUR JOURNEY", Color(0.36, 0.15, 0.58))
    begin_button.pressed.connect(_start_new_game)
    layout.add_child(begin_button)

    continue_button = _make_button("CONTINUE JOURNEY", Color(0.19, 0.12, 0.32))
    continue_button.pressed.connect(_continue_game)
    layout.add_child(continue_button)

    var controls := Label.new()
    controls.text = "WASD / arrows: move   •   Space: jump   •   Shift: run\nE: interact   •   Q: arcane pulse   •   Esc: release mouse"
    controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    controls.add_theme_font_size_override("font_size", 12)
    controls.add_theme_color_override("font_color", Color(0.68, 0.63, 0.75))
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

    var dialogue_button := _make_button("CONTINUE", Color(0.31, 0.13, 0.48))
    dialogue_button.pressed.connect(_advance_dialogue)
    dialogue_layout.add_child(dialogue_button)

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
        _show_dialogue("CHAPTER I • GLOAMWICK", "The violet sky above Gloamwick flickers like a dying candle. Three riftbound shapes have broken through the old ward and cornered Mathias, Battle Mage of the Council of Wizards, Warlocks & Witches. He raises a trembling hand as the ward-stones crack. “Apprentice! If you can hear me, help me drive them back. The Council's seals are failing—and something beneath the Realm has begun to wake.”", "Face the riftbound")
    else:
        _show_dialogue("WELCOME BACK, " + player_name.to_upper(), "Your Chronicle is intact. Mathias still watches the failing ward-stones, and the path ahead remains yours to choose.", "Return to the Realm")

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

    _add_box("Gloamwick Ground", Vector3(0, -0.5, 0), Vector3(120, 1, 120), Color(0.09, 0.075, 0.12), true)
    _add_box("Town Square", Vector3(0, 0.02, 0), Vector3(18, 0.12, 22), Color(0.18, 0.15, 0.22), false)
    _build_house(Vector3(-12, 0, -2), Color(0.18, 0.09, 0.21))
    _build_house(Vector3(12, 0, -4), Color(0.13, 0.12, 0.2))
    _build_house(Vector3(-12, 0, 13), Color(0.16, 0.08, 0.17))
    _build_tree(Vector3(-20, 0, -14), 5.0)
    _build_tree(Vector3(19, 0, -17), 6.0)
    _build_tree(Vector3(-22, 0, 18), 5.5)
    _build_tree(Vector3(23, 0, 17), 4.5)
    _add_box("Old Wardstone", Vector3(0, 1.0, -15), Vector3(1.0, 2.0, 1.0), Color(0.28, 0.15, 0.42), false)
    _add_box("Sanctuary Gate", Vector3(0, 3.0, -31), Vector3(10, 6, 0.8), Color(0.12, 0.075, 0.19), false)
    sanctuary_gate = _make_sigil(Vector3(0, 2.4, -30.45), Color(0.38, 0.12, 0.75), 2.1)
    sanctuary_gate.name = "Sigil Sanctuary Gate"
    add_child(sanctuary_gate)

    mathias = _build_person("Mathias", Vector3(0, 0, -5.5), Color(0.16, 0.11, 0.28), Color(0.8, 0.72, 0.92), true)
    for i in range(3):
        var x := -3.2 + float(i) * 3.2
        var enemy := _build_person("Riftbound " + str(i + 1), Vector3(x, 0, -9.0), Color(0.035, 0.02, 0.07), Color(0.56, 0.18, 0.75), false)
        enemy_nodes.append(enemy)
        enemy_hp[enemy.get_instance_id()] = 1

    var sigil_positions := [Vector3(-8.0, 0.0, -18.0), Vector3(8.0, 0.0, -18.0), Vector3(0.0, 0.0, -24.0)]
    var sigil_names := ["Dawn", "Dusk", "Heart"]
    var sigil_colors := [Color(0.98, 0.66, 0.24), Color(0.52, 0.35, 0.95), Color(0.28, 0.85, 0.72)]
    for i in range(3):
        var shrine := _make_sigil(sigil_positions[i] + Vector3(0, 1.1, 0), sigil_colors[i], 0.75)
        shrine.name = sigil_names[i] + " Sigil"
        shrine.set_meta("sigil_name", sigil_names[i])
        shrine.visible = i >= collected_sigils
        sigil_nodes.append(shrine)
        add_child(shrine)

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "PlayerWizard"
    player.position = Vector3(0, 0, 7.5)
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

func _build_house(pos: Vector3, color: Color) -> void:
    _add_box("Gloamwick House", pos + Vector3(0, 1.6, 0), Vector3(6, 3.2, 5), color, true)
    _add_box("House Roof", pos + Vector3(0, 3.55, 0), Vector3(6.8, 0.55, 5.8), Color(0.07, 0.035, 0.09), false)
    _add_box("House Door", pos + Vector3(0, 0.9, -2.55), Vector3(1.0, 1.8, 0.12), Color(0.08, 0.035, 0.08), false)

func _build_tree(pos: Vector3, height: float) -> void:
    var trunk := MeshInstance3D.new()
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.25
    trunk_mesh.bottom_radius = 0.48
    trunk_mesh.height = height
    trunk.mesh = trunk_mesh
    trunk.position = pos + Vector3(0, height * 0.5, 0)
    trunk.material_override = _material(Color(0.09, 0.045, 0.07))
    add_child(trunk)
    var crown := MeshInstance3D.new()
    var crown_mesh := SphereMesh.new()
    crown_mesh.radius = 1.8
    crown_mesh.height = 3.6
    crown.mesh = crown_mesh
    crown.position = pos + Vector3(0, height + 0.9, 0)
    crown.scale = Vector3(1.0, 1.35, 0.9)
    crown.material_override = _material(Color(0.035, 0.06, 0.055))
    add_child(crown)

func _build_person(person_name: String, pos: Vector3, robe_color: Color, glow_color: Color, is_mage: bool) -> Node3D:
    var person := Node3D.new()
    person.name = person_name
    person.position = pos
    _add_person_visual(person, robe_color, glow_color, is_mage)
    add_child(person)
    return person

func _add_person_visual(parent: Node3D, robe_color: Color, face_color: Color, is_mage: bool) -> void:
    var robe := MeshInstance3D.new()
    var robe_mesh := CylinderMesh.new()
    robe_mesh.top_radius = 0.22
    robe_mesh.bottom_radius = 0.52
    robe_mesh.height = 1.15
    robe.mesh = robe_mesh
    robe.position.y = 0.72
    robe.material_override = _material(robe_color)
    parent.add_child(robe)

    var face := MeshInstance3D.new()
    var face_mesh := SphereMesh.new()
    face_mesh.radius = 0.29
    face_mesh.height = 0.58
    face.mesh = face_mesh
    face.position.y = 1.48
    face.material_override = _material(Color(0.58, 0.42, 0.38) if is_mage else Color(0.07, 0.035, 0.12))
    parent.add_child(face)

    var hood := MeshInstance3D.new()
    var hood_mesh := SphereMesh.new()
    hood_mesh.radius = 0.37
    hood_mesh.height = 0.5
    hood.mesh = hood_mesh
    hood.position.y = 1.63
    hood.material_override = _material(robe_color.darkened(0.25))
    parent.add_child(hood)

    if is_mage:
        var hat := MeshInstance3D.new()
        var hat_mesh := CylinderMesh.new()
        hat_mesh.top_radius = 0.02
        hat_mesh.bottom_radius = 0.34
        hat_mesh.height = 0.6
        hat.mesh = hat_mesh
        hat.position.y = 2.03
        hat.material_override = _material(robe_color)
        parent.add_child(hat)
    else:
        parent.add_child(_make_sphere(Vector3(-0.11, 1.5, -0.245), 0.055, face_color))
        parent.add_child(_make_sphere(Vector3(0.11, 1.5, -0.245), 0.055, face_color))

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
        _show_dialogue("MATHIAS • BATTLE MAGE", "“The first wave is gone, but the ward is still bleeding light. I have served the Council for decades, and I have never seen a seal answer to something outside the Realm. Gather the three Sigils. Dawn, Dusk, Heart—remember their names. They are not keys alone; they are promises the Council made.”", "Continue")
        return

    if story_stage <= 1:
        var nearest_sigil := _nearest_node(sigil_nodes)
        if nearest_sigil != null and _distance_to(nearest_sigil) < 3.2:
            var sigil_name := str(nearest_sigil.get_meta("sigil_name", "Unknown"))
            nearest_sigil.visible = false
            sigil_nodes.erase(nearest_sigil)
            collected_sigils += 1
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

func _save_game() -> void:
    save_data.set_value("player", "name", player_name)
    save_data.set_value("player", "path", player_path)
    save_data.set_value("progress", "stage", story_stage)
    save_data.set_value("progress", "sigils", collected_sigils)
    save_data.set_value("world", "seed", WORLD_SEED)
    var err := save_data.save(SAVE_PATH)
    has_save = err == OK
    if continue_button != null:
        continue_button.disabled = not has_save
