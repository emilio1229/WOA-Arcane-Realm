extends Node3D

const WORLD_SIZE := 80.0
var player: CharacterBody3D
var camera_pivot: Node3D
var camera: Camera3D
var ui_layer: CanvasLayer
var menu_panel: PanelContainer
var hud_panel: PanelContainer
var dialogue_panel: PanelContainer
var name_input: LineEdit
var player_name := "Apprentice"
var started := false
var dialogue_open := false
var mouse_sensitivity := 0.0025
var pitch := -0.22
var story_step := 0
var prompt_label: Label
var status_label: Label
var dialogue_text: Label
var dialogue_title: Label
var interact_target: Node3D
var rune_shrines: Array[Node3D] = []
var collected_runes := 0
var objective_label: Label
var gate_seal: MeshInstance3D
var gate_portal: MeshInstance3D
var quest_complete := false
var guardian: Node3D
var guardian_hp := 8
var guardian_max_hp := 8
var guardian_attack_timer := 0.0
var player_hp := 5
var staff_cooldown := 0.0
var spell_cooldown := 0.0
var trial_started := false
var trial_complete := false
var jump_requested := false
var run_speed := 7.2
var walk_speed := 4.8

func _ready() -> void:
    _build_world()
    _build_player()
    _build_ui()
    _show_menu()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.sky = Sky.new()
    environment.sky.sky_material = ProceduralSkyMaterial.new()
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.48, 0.43, 0.62)
    environment.ambient_light_energy = 0.7
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -28, 0)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    add_child(sun)

    var floor_body := StaticBody3D.new()
    floor_body.name = "Ground"
    var floor_mesh := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(WORLD_SIZE, WORLD_SIZE)
    floor_mesh.mesh = plane
    var ground_mat := StandardMaterial3D.new()
    ground_mat.albedo_color = Color(0.105, 0.095, 0.16)
    ground_mat.roughness = 0.92
    floor_mesh.material_override = ground_mat
    floor_body.add_child(floor_mesh)
    var floor_collision := CollisionShape3D.new()
    var floor_shape := BoxShape3D.new()
    floor_shape.size = Vector3(WORLD_SIZE, 0.2, WORLD_SIZE)
    floor_collision.shape = floor_shape
    floor_collision.position.y = -0.1
    floor_body.add_child(floor_collision)
    add_child(floor_body)

    _add_platform(Vector3(0, 0.05, 0), Vector3(13, 0.3, 13), Color(0.19, 0.16, 0.27))
    for i in range(8):
        var angle := TAU * float(i) / 8.0
        var pos := Vector3(cos(angle) * 9.0, 0.0, sin(angle) * 9.0)
        _add_pillar(pos, 4.0 + float(i % 3) * 0.6)
    _add_pillar(Vector3(-5, 0, -12), 6.0)
    _add_pillar(Vector3(5, 0, -12), 6.0)
    _add_glowing_orb(Vector3(0, 3.0, -7.0))
    _create_mathias(Vector3(0, 0, -5.0))
    _add_path_lights()
    _add_sanctuary_architecture()
    _create_rune_shrine(Vector3(-5.8, 0.0, -9.0), "Dawn", Color(1.0, 0.63, 0.24))
    _create_rune_shrine(Vector3(5.8, 0.0, -9.0), "Dusk", Color(0.34, 0.62, 1.0))
    _create_rune_shrine(Vector3(0.0, 0.0, -15.0), "Heart", Color(0.74, 0.35, 1.0))
    _create_gate_portal()

func _add_platform(pos: Vector3, size: Vector3, color: Color) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.25
    material.roughness = 0.65
    mesh_instance.material_override = material
    body.add_child(mesh_instance)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)

func _add_pillar(pos: Vector3, height: float) -> void:
    var body := StaticBody3D.new()
    body.position = pos + Vector3(0, height * 0.5, 0)
    var mesh_instance := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.55
    mesh.bottom_radius = 0.78
    mesh.height = height
    mesh.radial_segments = 8
    mesh_instance.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.22, 0.19, 0.31)
    material.metallic = 0.3
    material.roughness = 0.72
    mesh_instance.material_override = material
    body.add_child(mesh_instance)
    var collision := CollisionShape3D.new()
    var shape := CylinderShape3D.new()
    shape.radius = 0.72
    shape.height = height
    collision.shape = shape
    body.add_child(collision)
    add_child(body)
    var rune := MeshInstance3D.new()
    var rune_mesh := BoxMesh.new()
    rune_mesh.size = Vector3(0.95, 0.08, 0.08)
    rune.mesh = rune_mesh
    rune.position = Vector3(0, height * 0.63, 0.0)
    var rune_mat := StandardMaterial3D.new()
    rune_mat.albedo_color = Color(0.78, 0.38, 1.0)
    rune_mat.emission_enabled = true
    rune_mat.emission = Color(0.48, 0.12, 1.0)
    rune_mat.emission_energy_multiplier = 2.0
    rune.material_override = rune_mat
    body.add_child(rune)

func _add_glowing_orb(pos: Vector3) -> void:
    var orb := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.65
    mesh.height = 1.3
    orb.mesh = mesh
    orb.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.72, 0.36, 1.0)
    mat.emission_enabled = true
    mat.emission = Color(0.46, 0.12, 1.0)
    mat.emission_energy_multiplier = 3.5
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    orb.material_override = mat
    add_child(orb)
    var light := OmniLight3D.new()
    light.position = pos
    light.light_color = Color(0.57, 0.24, 1.0)
    light.light_energy = 2.5
    light.omni_range = 9.0
    add_child(light)

func _create_mathias(pos: Vector3) -> void:
    var npc := Node3D.new()
    npc.name = "Mathias"
    npc.position = pos
    var robe := MeshInstance3D.new()
    var robe_mesh := CapsuleMesh.new()
    robe_mesh.radius = 0.48
    robe_mesh.height = 1.7
    robe.mesh = robe_mesh
    robe.position.y = 0.9
    var robe_mat := StandardMaterial3D.new()
    robe_mat.albedo_color = Color(0.15, 0.12, 0.29)
    robe_mat.metallic = 0.18
    robe.material_override = robe_mat
    npc.add_child(robe)
    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.29
    head_mesh.height = 0.58
    head.mesh = head_mesh
    head.position.y = 1.95
    var head_mat := StandardMaterial3D.new()
    head_mat.albedo_color = Color(0.75, 0.58, 0.43)
    head.material_override = head_mat
    npc.add_child(head)
    var hat := MeshInstance3D.new()
    var hat_mesh := CylinderMesh.new()
    hat_mesh.top_radius = 0.02
    hat_mesh.bottom_radius = 0.45
    hat_mesh.height = 0.75
    hat.mesh = hat_mesh
    hat.position.y = 2.42
    var hat_mat := StandardMaterial3D.new()
    hat_mat.albedo_color = Color(0.32, 0.12, 0.48)
    hat.material_override = hat_mat
    npc.add_child(hat)
    var staff := MeshInstance3D.new()
    var staff_mesh := CylinderMesh.new()
    staff_mesh.top_radius = 0.045
    staff_mesh.bottom_radius = 0.06
    staff_mesh.height = 2.0
    staff.mesh = staff_mesh
    staff.position = Vector3(0.7, 1.0, 0)
    staff.rotation_degrees.z = -8
    var staff_mat := StandardMaterial3D.new()
    staff_mat.albedo_color = Color(0.42, 0.24, 0.15)
    staff.material_override = staff_mat
    npc.add_child(staff)
    add_child(npc)
    interact_target = npc

func _add_path_lights() -> void:
    for z in range(2, 23, 4):
        for side in [-1.0, 1.0]:
            var light := OmniLight3D.new()
            light.position = Vector3(side * 3.3, 1.0, float(z) * -1.0)
            light.light_color = Color(0.42, 0.18, 0.85)
            light.light_energy = 0.75
            light.omni_range = 4.0
            add_child(light)
            var stone := MeshInstance3D.new()
            var mesh := CylinderMesh.new()
            mesh.top_radius = 0.2
            mesh.bottom_radius = 0.28
            mesh.height = 0.45
            stone.mesh = mesh
            stone.position = Vector3(side * 3.3, 0.22, float(z) * -1.0)
            var mat := StandardMaterial3D.new()
            mat.albedo_color = Color(0.25, 0.2, 0.34)
            stone.material_override = mat
            add_child(stone)

func _add_sanctuary_architecture() -> void:
    _add_platform(Vector3(0, 0.0, -19.0), Vector3(12.0, 0.5, 2.0), Color(0.12, 0.10, 0.20))
    for side in [-1.0, 1.0]:
        var pier := MeshInstance3D.new()
        var pier_mesh := BoxMesh.new()
        pier_mesh.size = Vector3(1.15, 7.0, 1.0)
        pier.mesh = pier_mesh
        pier.position = Vector3(side * 4.3, 3.5, -19.0)
        var pier_mat := _stone_material(Color(0.19, 0.16, 0.29), 0.35)
        pier.material_override = pier_mat
        add_child(pier)
        var cap := MeshInstance3D.new()
        var cap_mesh := BoxMesh.new()
        cap_mesh.size = Vector3(1.6, 0.3, 1.35)
        cap.mesh = cap_mesh
        cap.position = Vector3(side * 4.3, 7.05, -19.0)
        cap.material_override = _glow_material(Color(0.65, 0.25, 1.0))
        add_child(cap)
    var lintel := MeshInstance3D.new()
    var lintel_mesh := BoxMesh.new()
    lintel_mesh.size = Vector3(9.4, 0.9, 1.0)
    lintel.mesh = lintel_mesh
    lintel.position = Vector3(0, 7.1, -19.0)
    lintel.material_override = _stone_material(Color(0.24, 0.19, 0.35), 0.35)
    add_child(lintel)
    for ring_index in range(3):
        var ring := MeshInstance3D.new()
        var ring_mesh := TorusMesh.new()
        ring_mesh.inner_radius = 2.1 + float(ring_index) * 0.45
        ring_mesh.outer_radius = ring_mesh.inner_radius + 0.055
        ring.mesh = ring_mesh
        ring.position = Vector3(0, 0.23 + float(ring_index) * 0.012, 0)
        ring.material_override = _glow_material(Color(0.52 + float(ring_index) * 0.08, 0.18, 0.95))
        add_child(ring)
    for z in range(0, 4):
        for side in [-1.0, 1.0]:
            var crystal := MeshInstance3D.new()
            var crystal_mesh := PrismMesh.new()
            crystal_mesh.size = Vector3(0.65, 1.35, 0.65)
            crystal.mesh = crystal_mesh
            crystal.position = Vector3(side * 5.2, 0.85, -5.0 - float(z) * 4.0)
            crystal.rotation_degrees = Vector3(0, float(z) * 17.0, 12.0 * side)
            crystal.material_override = _glow_material(Color(0.35, 0.12, 0.85))
            add_child(crystal)
            var crystal_light := OmniLight3D.new()
            crystal_light.position = crystal.position
            crystal_light.light_color = Color(0.48, 0.18, 0.95)
            crystal_light.light_energy = 0.8
            crystal_light.omni_range = 4.5
            add_child(crystal_light)

func _stone_material(color: Color, metallic_value: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic_value
    material.roughness = 0.58
    return material

func _glow_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 1.6
    material.metallic = 0.15
    material.roughness = 0.32
    return material

func _create_rune_shrine(pos: Vector3, rune_title: String, rune_color: Color) -> void:
    var shrine := Node3D.new()
    shrine.name = rune_title + " Sigil"
    shrine.position = pos
    var pedestal := MeshInstance3D.new()
    var pedestal_mesh := BoxMesh.new()
    pedestal_mesh.size = Vector3(1.45, 0.48, 1.45)
    pedestal.mesh = pedestal_mesh
    pedestal.position.y = 0.24
    pedestal.material_override = _stone_material(Color(0.13, 0.10, 0.22), 0.45)
    shrine.add_child(pedestal)
    var upper := MeshInstance3D.new()
    var upper_mesh := CylinderMesh.new()
    upper_mesh.top_radius = 0.52
    upper_mesh.bottom_radius = 0.68
    upper_mesh.height = 0.25
    upper.mesh = upper_mesh
    upper.position.y = 0.57
    upper.material_override = _stone_material(Color(0.25, 0.18, 0.37), 0.35)
    shrine.add_child(upper)
    var crystal := MeshInstance3D.new()
    var crystal_mesh := PrismMesh.new()
    crystal_mesh.size = Vector3(0.62, 1.28, 0.62)
    crystal.mesh = crystal_mesh
    crystal.position.y = 1.35
    crystal.rotation_degrees = Vector3(0, 18, 8)
    crystal.material_override = _glow_material(rune_color)
    shrine.add_child(crystal)
    var ring := MeshInstance3D.new()
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.48
    ring_mesh.outer_radius = 0.55
    ring.mesh = ring_mesh
    ring.position.y = 1.35
    ring.material_override = _glow_material(rune_color.lightened(0.18))
    shrine.add_child(ring)
    var light := OmniLight3D.new()
    light.position.y = 1.4
    light.light_color = rune_color
    light.light_energy = 1.1
    light.omni_range = 5.5
    shrine.add_child(light)
    var label := Label3D.new()
    label.text = rune_title.to_upper() + " SIGIL"
    label.position.y = 2.35
    label.font_size = 32
    label.pixel_size = 0.008
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.modulate = rune_color.lightened(0.3)
    shrine.add_child(label)
    add_child(shrine)
    rune_shrines.append(shrine)

func _create_gate_portal() -> void:
    gate_seal = MeshInstance3D.new()
    var seal_mesh := BoxMesh.new()
    seal_mesh.size = Vector3(6.8, 5.8, 0.16)
    gate_seal.mesh = seal_mesh
    gate_seal.position = Vector3(0, 3.4, -19.0)
    gate_seal.material_override = _glow_material(Color(0.16, 0.06, 0.31))
    add_child(gate_seal)
    gate_portal = MeshInstance3D.new()
    var portal_mesh := SphereMesh.new()
    portal_mesh.radius = 1.0
    portal_mesh.height = 2.0
    gate_portal.mesh = portal_mesh
    gate_portal.scale = Vector3(2.35, 2.85, 0.08)
    gate_portal.position = Vector3(0, 3.45, -19.22)
    gate_portal.material_override = _glow_material(Color(0.2, 0.62, 1.0))
    gate_portal.hide()
    add_child(gate_portal)
    var portal_ring := MeshInstance3D.new()
    var portal_ring_mesh := TorusMesh.new()
    portal_ring_mesh.inner_radius = 2.55
    portal_ring_mesh.outer_radius = 2.72
    portal_ring.mesh = portal_ring_mesh
    portal_ring.position = Vector3(0, 3.45, -19.25)
    portal_ring.rotation_degrees.x = 90
    portal_ring.material_override = _glow_material(Color(0.3, 0.75, 1.0))
    add_child(portal_ring)

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 0.2, 5.0)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.8
    collision.shape = capsule
    collision.position.y = 0.9
    player.add_child(collision)
    var body_mesh := MeshInstance3D.new()
    var body_shape := CapsuleMesh.new()
    body_shape.radius = 0.38
    body_shape.height = 1.8
    body_mesh.mesh = body_shape
    body_mesh.position.y = 0.9
    var body_mat := StandardMaterial3D.new()
    body_mat.albedo_color = Color(0.18, 0.35, 0.62)
    body_mat.metallic = 0.2
    body_mesh.material_override = body_mat
    player.add_child(body_mesh)
    var head := MeshInstance3D.new()
    var head_shape := SphereMesh.new()
    head_shape.radius = 0.25
    head_shape.height = 0.5
    head.mesh = head_shape
    head.position.y = 1.95
    var head_mat := StandardMaterial3D.new()
    head_mat.albedo_color = Color(0.72, 0.55, 0.43)
    head.material_override = head_mat
    player.add_child(head)
    camera_pivot = Node3D.new()
    camera_pivot.position.y = 1.45
    player.add_child(camera_pivot)
    camera = Camera3D.new()
    camera.position = Vector3(0, 1.2, 5.4)
    camera.rotation.x = -0.18
    camera.current = true
    camera_pivot.add_child(camera)
    add_child(player)

func _build_ui() -> void:
    ui_layer = CanvasLayer.new()
    add_child(ui_layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var ui_theme := Theme.new()
    ui_theme.set_color("font_color", "Label", Color(0.91, 0.87, 1.0))
    ui_theme.set_color("font_color", "Button", Color(0.97, 0.92, 1.0))
    ui_theme.set_color("font_hover_color", "Button", Color(1.0, 0.84, 0.65))
    ui_theme.set_font_size("font_size", "Button", 16)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.055, 0.035, 0.105, 0.94)
    panel_style.border_color = Color(0.52, 0.27, 0.82, 0.95)
    panel_style.set_border_width_all(2)
    panel_style.set_corner_radius_all(12)
    panel_style.content_margin_left = 22
    panel_style.content_margin_right = 22
    panel_style.content_margin_top = 18
    panel_style.content_margin_bottom = 18
    ui_theme.set_stylebox("panel", "PanelContainer", panel_style)
    var button_style := StyleBoxFlat.new()
    button_style.bg_color = Color(0.24, 0.10, 0.42, 1.0)
    button_style.border_color = Color(0.68, 0.38, 0.95, 1.0)
    button_style.set_border_width_all(1)
    button_style.set_corner_radius_all(8)
    button_style.content_margin_left = 12
    button_style.content_margin_right = 12
    button_style.content_margin_top = 8
    button_style.content_margin_bottom = 8
    ui_theme.set_stylebox("normal", "Button", button_style)
    var button_hover := button_style.duplicate() as StyleBoxFlat
    button_hover.bg_color = Color(0.36, 0.15, 0.56, 1.0)
    ui_theme.set_stylebox("hover", "Button", button_hover)
    var button_pressed := button_style.duplicate() as StyleBoxFlat
    button_pressed.bg_color = Color(0.15, 0.07, 0.29, 1.0)
    ui_theme.set_stylebox("pressed", "Button", button_pressed)
    root.theme = ui_theme
    ui_layer.add_child(root)

    menu_panel = PanelContainer.new()
    menu_panel.set_anchors_preset(Control.PRESET_CENTER)
    menu_panel.position = Vector2(-250, -205)
    menu_panel.size = Vector2(500, 410)
    menu_panel.custom_minimum_size = Vector2(500, 410)
    root.add_child(menu_panel)
    var menu_box := VBoxContainer.new()
    menu_box.add_theme_constant_override("separation", 14)
    menu_panel.add_child(menu_box)
    var title := Label.new()
    title.text = "WOA: ARCANE REALM"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    title.add_theme_color_override("font_color", Color(0.82, 0.63, 1.0))
    menu_box.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "THE SIGIL AWAKENS"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 15)
    menu_box.add_child(subtitle)
    var intro := Label.new()
    intro.text = "A forgotten sanctuary stirs beneath a violet sky.\nYour story begins with a name."
    intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    menu_box.add_child(intro)
    name_input = LineEdit.new()
    name_input.placeholder_text = "Enter your wizard's name"
    name_input.text = ""
    name_input.custom_minimum_size.y = 42
    menu_box.add_child(name_input)
    var start_button := Button.new()
    start_button.text = "BEGIN YOUR STORY"
    start_button.custom_minimum_size.y = 48
    start_button.pressed.connect(_on_start_pressed)
    menu_box.add_child(start_button)
    var hint := Label.new()
    hint.text = "WASD / arrows move  •  Mouse look  •  Space jump  •  E speak  •  Shift run"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 12)
    menu_box.add_child(hint)

    hud_panel = PanelContainer.new()
    hud_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    hud_panel.position = Vector2(20, 20)
    hud_panel.custom_minimum_size = Vector2(360, 112)
    root.add_child(hud_panel)
    var hud_box := VBoxContainer.new()
    hud_panel.add_child(hud_box)
    status_label = Label.new()
    status_label.text = "Apprentice  |  The Sigil Sanctuary"
    status_label.add_theme_color_override("font_color", Color(0.87, 0.75, 1.0))
    hud_box.add_child(status_label)
    prompt_label = Label.new()
    prompt_label.text = "Find Mathias near the glowing sigil."
    hud_box.add_child(prompt_label)

    dialogue_panel = PanelContainer.new()
    dialogue_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    dialogue_panel.offset_left = 100
    dialogue_panel.offset_right = -100
    dialogue_panel.offset_top = -205
    dialogue_panel.offset_bottom = -25
    root.add_child(dialogue_panel)
    var dialog_box := VBoxContainer.new()
    dialog_box.add_theme_constant_override("separation", 8)
    dialogue_panel.add_child(dialog_box)
    dialogue_title = Label.new()
    dialogue_title.add_theme_font_size_override("font_size", 22)
    dialogue_title.add_theme_color_override("font_color", Color(0.82, 0.63, 1.0))
    dialog_box.add_child(dialogue_title)
    dialogue_text = Label.new()
    dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialogue_text.custom_minimum_size.y = 75
    dialog_box.add_child(dialogue_text)
    var continue_button := Button.new()
    continue_button.text = "Continue  [E]"
    continue_button.pressed.connect(_advance_dialogue)
    dialog_box.add_child(continue_button)
    hud_panel.hide()
    dialogue_panel.hide()

func _show_menu() -> void:
    menu_panel.show()
    hud_panel.hide()
    dialogue_panel.hide()
    started = false

func _on_start_pressed() -> void:
    player_name = name_input.text.strip_edges()
    if player_name.is_empty():
        player_name = "Apprentice"
    status_label.text = player_name + "  |  The Sigil Sanctuary"
    objective_label.text = "Quest: Speak with Mathias"
    menu_panel.hide()
    hud_panel.show()
    started = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _open_dialogue("Mathias", "At last. The sanctuary has been waiting for you, " + player_name + ". I am Mathias, keeper of the first sigil. The light above us has begun to answer a call that should have remained silent.", 0)

func _input(event: InputEvent) -> void:
    if not started:
        if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
            _on_start_pressed()
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not dialogue_open:
        # Web browsers only allow pointer lock in direct response to a click.
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not dialogue_open:
        camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
        pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -0.55, 0.28)
        camera.rotation.x = pitch
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        elif event.keycode == KEY_SPACE:
            jump_requested = true
        elif event.keycode == KEY_E:
            if dialogue_open:
                _advance_dialogue()
            elif not trial_started:
                _try_interact()
        elif event.keycode == KEY_F and not dialogue_open:
            _staff_attack()
        elif event.keycode == KEY_Q and not dialogue_open:
            _cast_arcane_bolt()

func _physics_process(delta: float) -> void:
    if not started or dialogue_open:
        player.velocity.x = move_toward(player.velocity.x, 0.0, 22.0 * delta)
        player.velocity.z = move_toward(player.velocity.z, 0.0, 22.0 * delta)
        if not player.is_on_floor():
            player.velocity.y -= 22.0 * delta
        player.move_and_slide()
        jump_requested = false
        return

    var input_vector := Vector2.ZERO
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input_vector.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input_vector.y += 1.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input_vector.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input_vector.x += 1.0
    input_vector = input_vector.normalized()

    var forward := -camera_pivot.global_basis.z
    forward.y = 0.0
    forward = forward.normalized()
    var right := camera_pivot.global_basis.x
    right.y = 0.0
    right = right.normalized()
    var direction := (right * input_vector.x + forward * -input_vector.y).normalized()
    var speed := run_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed

    if direction.length() > 0.01:
        player.velocity.x = direction.x * speed
        player.velocity.z = direction.z * speed
        player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), min(1.0, delta * 12.0))
    else:
        player.velocity.x = move_toward(player.velocity.x, 0.0, 24.0 * delta)
        player.velocity.z = move_toward(player.velocity.z, 0.0, 24.0 * delta)

    if not player.is_on_floor():
        player.velocity.y -= 22.0 * delta
    elif jump_requested:
        player.velocity.y = 7.0
    jump_requested = false
    player.move_and_slide()
    staff_cooldown = maxf(0.0, staff_cooldown - delta)
    spell_cooldown = maxf(0.0, spell_cooldown - delta)
    if trial_started:
        _update_guardian(delta)
        prompt_label.text = "F: staff strike  •  Q: arcane bolt  •  keep moving!"
        return

    var nearest_rune_distance := 999.0
    for shrine in rune_shrines:
        nearest_rune_distance = min(nearest_rune_distance, player.global_position.distance_to(shrine.global_position))
    var mathias_distance := player.global_position.distance_to(interact_target.global_position)
    var gate_distance := player.global_position.distance_to(Vector3(0, 0, -19))
    if mathias_distance < 4.5 and (mathias_distance <= nearest_rune_distance or story_step < 2):
        prompt_label.text = "Press E to speak with Mathias"
    elif nearest_rune_distance < 3.6:
        prompt_label.text = "Press E to claim the " + _nearest_rune_name() + " Sigil"
    elif gate_distance < 5.5:
        prompt_label.text = "Press E to enter the awakened gate" if quest_complete else "The gate is sealed • recover all 3 sigils"
    elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
        prompt_label.text = "Click the world to look around • ESC releases the cursor"
    else:
        prompt_label.text = "Recover the three sigils • Shift to run"

func _nearest_rune_name() -> String:
    var nearest_name := "Ancient"
    var nearest_distance := 999.0
    for shrine in rune_shrines:
        var distance := player.global_position.distance_to(shrine.global_position)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest_name = shrine.name.replace(" Sigil", "")
    return nearest_name

func _try_interact() -> void:
    var mathias_distance := player.global_position.distance_to(interact_target.global_position)
    var nearest_shrine: Node3D = null
    var nearest_distance := 999.0
    for shrine in rune_shrines:
        var distance := player.global_position.distance_to(shrine.global_position)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest_shrine = shrine
    if mathias_distance < 4.5 and (mathias_distance <= nearest_distance or story_step < 2):
        _interact_with_mathias()
        return
    if nearest_shrine != null and nearest_distance < 3.6:
        _collect_rune(nearest_shrine)
        return
    if player.global_position.distance_to(Vector3(0, 0, -19)) < 5.5:
        if quest_complete and not trial_complete:
            _start_first_trial()
        elif trial_complete:
            _open_dialogue("The Awakened Gate", "The first guardian has fallen, and the sanctuary wards burn bright once more. Beyond this threshold lie deeper ruins, forgotten forests, and the mysteries of the Arcane Realm. Your journey has only begun.", 3)
        else:
            _open_dialogue("Sealed Gate", "Three ancient sigils anchor this ward. Dawn, Dusk, and Heart must be returned before the gate will answer.", 2)

func _collect_rune(shrine: Node3D) -> void:
    var rune_name := shrine.name.replace(" Sigil", "")
    rune_shrines.erase(shrine)
    shrine.queue_free()
    collected_runes += 1
    objective_label.text = "Quest: Recover the sigils (%d/3)" % collected_runes
    if collected_runes >= 3:
        quest_complete = true
        gate_seal.hide()
        gate_portal.show()
        objective_label.text = "Quest complete: Enter the awakened gate"
        _open_dialogue("Sigil Awakened", "The " + rune_name + " Sigil rises into the air and the other two answer. Light races across the sanctuary. The gate is open. Whatever waits beyond it now knows your name.", 2)
    else:
        _open_dialogue(rune_name + " Sigil", "The crystal loosens from its ancient mooring and folds into a ribbon of light. The ward recognizes your touch. " + str(3 - collected_runes) + " sigil(s) remain.", 2)

func _start_first_trial() -> void:
    if trial_started or trial_complete:
        return
    trial_started = true
    _add_platform(Vector3(0, 0.05, -32), Vector3(22, 0.4, 22), Color(0.105, 0.085, 0.16))
    for i in range(8):
        var angle := TAU * float(i) / 8.0
        var rune := MeshInstance3D.new()
        var rune_mesh := BoxMesh.new()
        rune_mesh.size = Vector3(0.9, 0.045, 0.09)
        rune.mesh = rune_mesh
        rune.position = Vector3(cos(angle) * 7.2, 0.29, -32.0 + sin(angle) * 7.2)
        rune.rotation.y = -angle
        rune.material_override = _glow_material(Color(0.48, 0.18, 0.78))
        add_child(rune)
    player.global_position = Vector3(0, 0.3, -24.0)
    player.velocity = Vector3.ZERO
    guardian_hp = guardian_max_hp
    player_hp = 5
    guardian_attack_timer = 1.0
    _create_guardian(Vector3(0, 0.3, -36.0))
    status_label.text = player_name + "  |  HP " + str(player_hp) + "/5"
    objective_label.text = "First Trial: Defeat the sanctuary guardian"
    _open_dialogue("The First Trial", "The gate folds shut behind you. From the heart of the arena, a guardian rises in blackened armor, its core burning with stolen sigil-light. Strike with F when close. Cast an arcane bolt with Q from a distance. Keep moving — the guardian will not wait.", 2)

func _create_guardian(pos: Vector3) -> void:
    guardian = Node3D.new()
    guardian.name = "Sanctuary Guardian"
    guardian.position = pos
    var shadow_body := MeshInstance3D.new()
    var body_mesh := CapsuleMesh.new()
    body_mesh.radius = 0.72
    body_mesh.height = 2.6
    shadow_body.mesh = body_mesh
    shadow_body.position.y = 1.3
    shadow_body.material_override = _stone_material(Color(0.105, 0.075, 0.14), 0.72)
    guardian.add_child(shadow_body)
    var chest := MeshInstance3D.new()
    var chest_mesh := SphereMesh.new()
    chest_mesh.radius = 0.42
    chest_mesh.height = 0.84
    chest.mesh = chest_mesh
    chest.position = Vector3(0, 1.55, -0.55)
    chest.material_override = _glow_material(Color(0.8, 0.12, 0.36))
    guardian.add_child(chest)
    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.48
    head_mesh.height = 0.96
    head.mesh = head_mesh
    head.position.y = 2.55
    head.material_override = _stone_material(Color(0.17, 0.11, 0.21), 0.55)
    guardian.add_child(head)
    for side in [-1.0, 1.0]:
        var horn := MeshInstance3D.new()
        var horn_mesh := CylinderMesh.new()
        horn_mesh.top_radius = 0.015
        horn_mesh.bottom_radius = 0.22
        horn_mesh.height = 0.85
        horn.mesh = horn_mesh
        horn.position = Vector3(side * 0.38, 3.05, 0)
        horn.rotation_degrees.z = -side * 32.0
        horn.material_override = _stone_material(Color(0.38, 0.28, 0.42), 0.25)
        guardian.add_child(horn)
    var eye_light := OmniLight3D.new()
    eye_light.position = Vector3(0, 2.4, -0.4)
    eye_light.light_color = Color(0.95, 0.08, 0.3)
    eye_light.light_energy = 1.8
    eye_light.omni_range = 6.0
    guardian.add_child(eye_light)
    add_child(guardian)

func _staff_attack() -> void:
    if not trial_started or guardian == null or staff_cooldown > 0.0:
        return
    if player.global_position.distance_to(guardian.global_position) > 3.2:
        prompt_label.text = "Move closer for a staff strike!"
        return
    staff_cooldown = 0.48
    guardian_hp -= 1
    _show_guardian_hit(Color(0.88, 0.5, 1.0))
    objective_label.text = "Guardian: %d/%d HP  •  Your HP: %d/5" % [maxi(0, guardian_hp), guardian_max_hp, player_hp]
    if guardian_hp <= 0:
        _defeat_guardian()

func _cast_arcane_bolt() -> void:
    if not trial_started or guardian == null or spell_cooldown > 0.0:
        return
    if player.global_position.distance_to(guardian.global_position) > 16.0:
        prompt_label.text = "The guardian is beyond your spell's reach."
        return
    spell_cooldown = 0.85
    var bolt := MeshInstance3D.new()
    var bolt_mesh := SphereMesh.new()
    bolt_mesh.radius = 0.22
    bolt_mesh.height = 0.44
    bolt.mesh = bolt_mesh
    bolt.position = player.global_position + Vector3(0, 1.35, 0)
    bolt.material_override = _glow_material(Color(0.36, 0.72, 1.0))
    add_child(bolt)
    var tween := create_tween()
    tween.tween_property(bolt, "global_position", guardian.global_position + Vector3(0, 1.4, 0), 0.2)
    tween.finished.connect(func(): bolt.queue_free())
    guardian_hp -= 2
    _show_guardian_hit(Color(0.35, 0.72, 1.0))
    objective_label.text = "Guardian: %d/%d HP  •  Your HP: %d/5" % [maxi(0, guardian_hp), guardian_max_hp, player_hp]
    if guardian_hp <= 0:
        _defeat_guardian()

func _show_guardian_hit(hit_color: Color) -> void:
    if guardian == null:
        return
    var flash := MeshInstance3D.new()
    var flash_mesh := SphereMesh.new()
    flash_mesh.radius = 0.75
    flash_mesh.height = 1.5
    flash.mesh = flash_mesh
    flash.position = Vector3(0, 1.5, 0)
    flash.material_override = _glow_material(hit_color)
    guardian.add_child(flash)
    get_tree().create_timer(0.12).timeout.connect(func():
        if is_instance_valid(flash):
            flash.queue_free()
    )

func _update_guardian(delta: float) -> void:
    if guardian == null or not is_instance_valid(guardian):
        return
    guardian_attack_timer -= delta
    var to_player := player.global_position - guardian.global_position
    to_player.y = 0.0
    var distance := to_player.length()
    if distance > 1.9:
        var step := to_player.normalized() * 2.0 * delta
        guardian.position += step
        guardian.look_at(Vector3(player.global_position.x, guardian.global_position.y, player.global_position.z), Vector3.UP)
    elif guardian_attack_timer <= 0.0:
        player_hp -= 1
        guardian_attack_timer = 1.25
        status_label.text = player_name + "  |  HP " + str(maxi(0, player_hp)) + "/5"
        objective_label.text = "Guardian: %d/%d HP  •  Your HP: %d/5" % [guardian_hp, guardian_max_hp, maxi(0, player_hp)]
        _show_guardian_hit(Color(1.0, 0.12, 0.24))
        if player_hp <= 0:
            trial_started = false
            guardian.queue_free()
            guardian = null
            player.global_position = Vector3(0, 0.3, -15.0)
            player.velocity = Vector3.ZERO
            player_hp = 5
            status_label.text = player_name + "  |  HP 5/5"
            objective_label.text = "Trial failed. The gate will let you try again."
            _open_dialogue("The Trial Ends", "The guardian's strike drives you back through the ward. The sigils preserve your life, but the trial remains. Catch your breath and return to the gate when you are ready.", 2)

func _defeat_guardian() -> void:
    trial_started = false
    trial_complete = true
    if guardian != null:
        guardian.queue_free()
        guardian = null
    player_hp = 5
    status_label.text = player_name + "  |  HP 5/5"
    objective_label.text = "First Trial complete: The gate is yours"
    player.global_position = Vector3(0, 0.3, -15.0)
    player.velocity = Vector3.ZERO
    _open_dialogue("Guardian Defeated", "The guardian's core fractures into harmless light. The stolen sigil-energy returns to the sanctuary, and the old gate recognizes you as its keeper. This is the first victory of many, " + player_name + ".", 3)

func _interact_with_mathias() -> void:
    if story_step == 0:
        _open_dialogue("Mathias", "At last. The sanctuary has been waiting for you, " + player_name + ". I am Mathias, keeper of the first sigil. The light above us has begun to answer a call that should have remained silent.", 0)
    elif story_step == 1:
        _open_dialogue("Mathias", "The first sigil is not a weapon. It is a promise: power must answer to purpose. Something has breached the old wards, and the sanctuary is only the first place it has touched.", 1)
    else:
        objective_label.text = "Quest: Recover the three ancient sigils"
        _open_dialogue("Mathias", "Dawn, Dusk, and Heart. Three fragments hold the gate shut. Find their crystal shrines along the path and press E near each one to claim their sigil. Return to the arch when all three answer.", 2)

func _open_dialogue(who: String, words: String, step: int) -> void:
    story_step = step
    dialogue_open = true
    dialogue_title.text = who
    dialogue_text.text = words
    dialogue_panel.show()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _advance_dialogue() -> void:
    if story_step == 0:
        _open_dialogue("Mathias", "The first sigil is not a weapon. It is a promise: power must answer to purpose. Something has breached the old wards, and the sanctuary is only the first place it has touched.", 1)
    elif story_step == 1:
        _open_dialogue("Mathias", "Dawn, Dusk, and Heart. Three fragments hold the gate shut. Find their crystal shrines along the path and press E near each one to claim its sigil. Return to the arch when all three answer.", 2)
        objective_label.text = "Quest: Recover the three ancient sigils"
    else:
        dialogue_open = false
        dialogue_panel.hide()
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
