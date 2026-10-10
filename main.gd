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
    hint.text = "WASD move  •  Mouse look  •  Space jump  •  E interact"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 12)
    menu_box.add_child(hint)

    hud_panel = PanelContainer.new()
    hud_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    hud_panel.position = Vector2(20, 20)
    hud_panel.custom_minimum_size = Vector2(300, 76)
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
    menu_panel.hide()
    hud_panel.show()
    started = true
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _open_dialogue("Mathias", "At last. The sanctuary has been waiting for you, " + player_name + ". I am Mathias, keeper of the first sigil. The light above us has begun to answer a call that should have remained silent.", 0)

func _input(event: InputEvent) -> void:
    if not started:
        if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
            _on_start_pressed()
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not dialogue_open:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not dialogue_open:
        camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
        pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -0.72, 0.25)
        camera.rotation.x = pitch
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        elif event.keycode == KEY_E:
            if dialogue_open:
                _advance_dialogue()
            elif player.global_position.distance_to(interact_target.global_position) < 4.0:
                _interact_with_mathias()

func _physics_process(delta: float) -> void:
    if not started or dialogue_open:
        if player:
            player.velocity.x = move_toward(player.velocity.x, 0.0, 18.0 * delta)
            player.velocity.z = move_toward(player.velocity.z, 0.0, 18.0 * delta)
            if not player.is_on_floor():
                player.velocity.y -= 20.0 * delta
            player.move_and_slide()
        return
    var input_vector := Vector2(
        Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
        Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
    )
    if Input.is_key_pressed(KEY_W): input_vector.y = -1.0
    if Input.is_key_pressed(KEY_S): input_vector.y = 1.0
    if Input.is_key_pressed(KEY_A): input_vector.x = -1.0
    if Input.is_key_pressed(KEY_D): input_vector.x = 1.0
    input_vector = input_vector.normalized()
    var direction := (camera_pivot.global_basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
    direction.y = 0
    direction = direction.normalized()
    var speed := 5.2
    if direction.length() > 0.01:
        player.velocity.x = direction.x * speed
        player.velocity.z = direction.z * speed
        var look_direction := Vector3(direction.x, 0, direction.z)
        player.rotation.y = lerp_angle(player.rotation.y, atan2(-look_direction.x, -look_direction.z), delta * 10.0)
    else:
        player.velocity.x = move_toward(player.velocity.x, 0.0, 18.0 * delta)
        player.velocity.z = move_toward(player.velocity.z, 0.0, 18.0 * delta)
    if not player.is_on_floor():
        player.velocity.y -= 20.0 * delta
    elif Input.is_key_pressed(KEY_SPACE):
        player.velocity.y = 7.2
    player.move_and_slide()
    var near_mathias := player.global_position.distance_to(interact_target.global_position) < 4.0
    if near_mathias:
        prompt_label.text = "Press E to speak with Mathias"
    else:
        prompt_label.text = "Find Mathias near the glowing sigil."

func _interact_with_mathias() -> void:
    if story_step == 0:
        _open_dialogue("Mathias", "The first sigil is not a weapon. It is a promise: power must answer to purpose. Something has breached the old wards, and the sanctuary is only the first place it has touched.", 1)
    elif story_step == 1:
        _open_dialogue("Mathias", "Look toward the arch beyond the central platform. The runes there have gone dark. Find the source, and do not mistake every shadow for an enemy. The realm is testing you.", 2)
    else:
        _open_dialogue("Mathias", "The path is yours now, " + player_name + ". Explore the sanctuary, practice your movement, and return when you are ready to uncover what the sigil is hiding.", 2)

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
        _open_dialogue("Mathias", "Look toward the arch beyond the central platform. The runes there have gone dark. Find the source, and do not mistake every shadow for an enemy. The realm is testing you.", 2)
    else:
        dialogue_open = false
        dialogue_panel.hide()
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
