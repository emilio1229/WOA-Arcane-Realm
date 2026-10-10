extends Node3D

const WORLD_SIZE := 1200.0
const WORLD_SEED_DEFAULT := 730241
const DUNGEON_ORIGIN := Vector3(230.0, 0.0, 0.0)
const DUNGEON_FLOOR_SIZE := Vector2(72.0, 72.0)
var player: CharacterBody3D
var player_visual_root: Node3D
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
var collected_rune_names: Array[String] = []
var save_exists := false
var continue_button: Button
var character_select: OptionButton
var settings_panel: PanelContainer
var mouse_sensitivity_slider: HSlider
var invert_y := false
var selected_character := "Wizard"
var intro_battle_active := false
var intro_battle_finished := false
var intro_enemies: Array[Node3D] = []
var intro_enemy_hp: Dictionary = {}
var intro_enemy_attack_timer := 1.0
var animated_crystals: Array[MeshInstance3D] = []
var crystal_home_y: Dictionary = {}
var animation_clock := 0.0
var jump_requested := false
var run_speed := 7.2
var walk_speed := 4.8
var world_seed := WORLD_SEED_DEFAULT
var dungeon_seed := 0
var dungeon_active := false
var dungeon_return_position := Vector3(0.0, 0.3, 5.0)
var dungeon_root: Node3D
var dungeon_entrance: Node3D
var dungeon_exit: Node3D
var dungeon_label: Label
var generated_landmarks: Array[Node3D] = []

func _ready() -> void:
    world_seed = _read_saved_world_seed()
    _build_world()
    _build_player()
    _build_ui()
    _load_game()
    _show_menu()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
    animation_clock += delta
    for i in range(animated_crystals.size() - 1, -1, -1):
        var crystal := animated_crystals[i]
        if not is_instance_valid(crystal):
            animated_crystals.remove_at(i)
            continue
        crystal.rotate_y(delta * 0.7)
        var home_y := float(crystal_home_y.get(crystal.get_instance_id(), crystal.position.y))
        crystal.position.y = home_y + sin(animation_clock * 2.1 + float(i) * 0.8) * 0.065
    if guardian != null and is_instance_valid(guardian):
        guardian.position.y = 0.3 + sin(animation_clock * 2.4) * 0.045
    if player_visual_root != null and is_instance_valid(player_visual_root):
        var moving := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_RIGHT)
        var bob_speed := 10.0 if moving and started and not dialogue_open else 1.8
        var bob_amount := 0.035 if moving and started and not dialogue_open else 0.012
        player_visual_root.position.y = sin(animation_clock * bob_speed) * bob_amount
        player_visual_root.rotation.z = deg_to_rad(sin(animation_clock * 6.5) * 1.5) if moving and started and not dialogue_open else 0.0

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.sky = Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.018, 0.012, 0.052)
    sky_material.sky_horizon_color = Color(0.12, 0.055, 0.19)
    sky_material.ground_bottom_color = Color(0.018, 0.015, 0.03)
    sky_material.ground_horizon_color = Color(0.075, 0.045, 0.11)
    environment.sky.sky_material = sky_material
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.12, 0.075, 0.19)
    environment.fog_density = 0.006
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
    _build_starting_town()
    _create_mathias(Vector3(0, 0, -3.0))
    _add_path_lights()
    _add_haunted_trees()
    _add_sanctuary_architecture()
    _create_rune_shrine(Vector3(-5.8, 0.0, -9.0), "Dawn", Color(1.0, 0.63, 0.24))
    _create_rune_shrine(Vector3(5.8, 0.0, -9.0), "Dusk", Color(0.34, 0.62, 1.0))
    _create_rune_shrine(Vector3(0.0, 0.0, -15.0), "Heart", Color(0.74, 0.35, 1.0))
    _create_gate_portal()
    _generate_wilderness()
    _create_dungeon_entrance()


func _read_saved_world_seed() -> int:
    var path := "user://arcane_realm_save.json"
    if not FileAccess.file_exists(path):
        return WORLD_SEED_DEFAULT
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return WORLD_SEED_DEFAULT
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        return int(parsed.get("world_seed", WORLD_SEED_DEFAULT))
    return WORLD_SEED_DEFAULT


func _generate_wilderness() -> void:
    # Handcrafted story locations stay untouched in the central 100-metre sanctuary.
    # A stable seed means the same wilderness landmarks reappear after reloading.
    var rng := RandomNumberGenerator.new()
    rng.seed = world_seed
    var tree_scene: PackedScene = null
    var tree_model_path := "res://assets/models/environment/haunted blackwood tree 3d model.glb"
    # Git LFS pointer files are plain text, not valid GLB resources. Check the
    # binary header before loading so missing LFS objects use procedural trees.
    if ResourceLoader.exists(tree_model_path):
        var tree_file := FileAccess.open(tree_model_path, FileAccess.READ)
        if tree_file != null:
            var tree_header: String = tree_file.get_buffer(4).get_string_from_ascii()
            tree_file.close()
            if tree_header == "glTF":
                tree_scene = load(tree_model_path) as PackedScene
    for i in range(260):
        var x := rng.randf_range(-520.0, 520.0)
        var z := rng.randf_range(-520.0, 520.0)
        if Vector2(x, z).length() < 58.0:
            continue
        # Keep the dungeon approach clear and make a readable route from the town.
        if Vector2(x - DUNGEON_ORIGIN.x, z - DUNGEON_ORIGIN.z).length() < 28.0:
            continue
        var prop := Node3D.new()
        prop.name = "WildernessProp_%03d" % i
        prop.position = Vector3(x, 0.0, z)
        var roll := rng.randf()
        if roll < 0.67 and tree_scene != null:
            var tree := tree_scene.instantiate() as Node3D
            tree.scale = Vector3.ONE * rng.randf_range(0.65, 1.35)
            tree.rotation.y = rng.randf_range(0.0, TAU)
            prop.add_child(tree)
        elif roll < 0.84:
            var rock := MeshInstance3D.new()
            var mesh := SphereMesh.new()
            mesh.radius = rng.randf_range(0.65, 1.8)
            mesh.height = mesh.radius * rng.randf_range(0.7, 1.4)
            rock.mesh = mesh
            rock.position.y = mesh.radius * 0.45
            rock.rotation = Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(0.0, TAU), rng.randf_range(-0.25, 0.25))
            rock.material_override = _stone_material(Color(0.105, 0.085, 0.13), 0.15)
            prop.add_child(rock)
        else:
            var shard := MeshInstance3D.new()
            var shard_mesh := PrismMesh.new()
            shard_mesh.size = Vector3(rng.randf_range(1.0, 2.4), rng.randf_range(1.8, 4.5), rng.randf_range(1.0, 2.4))
            shard.mesh = shard_mesh
            shard.position.y = shard_mesh.size.y * 0.5
            shard.rotation.y = rng.randf_range(0.0, TAU)
            shard.material_override = _stone_material(Color(0.18, 0.1, 0.23), 0.4)
            prop.add_child(shard)
        add_child(prop)
    # Four distant landmarks make the world feel navigable without replacing story spaces.
    var landmarks := [
        {"name":"The Hollow Crown", "position":Vector3(-170,0,-135), "color":Color(0.36,0.17,0.55)},
        {"name":"Ashen Watch", "position":Vector3(185,0,-190), "color":Color(0.7,0.25,0.18)},
        {"name":"Moonwell", "position":Vector3(-230,0,185), "color":Color(0.2,0.45,0.8)},
        {"name":"The Fallen Archive", "position":Vector3(325,0,225), "color":Color(0.5,0.35,0.7)}
    ]
    for landmark_data in landmarks:
        var landmark := Node3D.new()
        landmark.name = str(landmark_data.name)
        landmark.position = landmark_data.position
        var plinth := MeshInstance3D.new()
        var plinth_mesh := CylinderMesh.new()
        plinth_mesh.top_radius = 2.0
        plinth_mesh.bottom_radius = 3.0
        plinth_mesh.height = 1.0
        plinth.mesh = plinth_mesh
        plinth.position.y = 0.5
        plinth.material_override = _stone_material(Color(0.12,0.085,0.17), 0.3)
        landmark.add_child(plinth)
        var crystal := MeshInstance3D.new()
        var crystal_mesh := PrismMesh.new()
        crystal_mesh.size = Vector3(1.2, 4.0, 1.2)
        crystal.mesh = crystal_mesh
        crystal.position.y = 3.0
        crystal.material_override = _glow_material(landmark_data.color)
        landmark.add_child(crystal)
        var light := OmniLight3D.new()
        light.position.y = 3.0
        light.light_color = landmark_data.color
        light.light_energy = 1.1
        light.omni_range = 13.0
        landmark.add_child(light)
        add_child(landmark)
        generated_landmarks.append(landmark)


func _create_dungeon_entrance() -> void:
    dungeon_entrance = Node3D.new()
    dungeon_entrance.name = "The Shifting Hollow Entrance"
    dungeon_entrance.position = DUNGEON_ORIGIN
    var arch := MeshInstance3D.new()
    var arch_mesh := BoxMesh.new()
    arch_mesh.size = Vector3(5.0, 6.0, 1.0)
    arch.mesh = arch_mesh
    arch.position.y = 3.0
    arch.material_override = _stone_material(Color(0.11, 0.07, 0.16), 0.25)
    dungeon_entrance.add_child(arch)
    var portal := MeshInstance3D.new()
    var portal_mesh := PlaneMesh.new()
    portal_mesh.size = Vector2(3.3, 4.6)
    portal.mesh = portal_mesh
    portal.position = Vector3(0.0, 2.8, -0.58)
    portal.material_override = _glow_material(Color(0.34, 0.12, 0.72))
    dungeon_entrance.add_child(portal)
    var lamp := OmniLight3D.new()
    lamp.position.y = 2.8
    lamp.light_color = Color(0.42, 0.16, 0.9)
    lamp.light_energy = 2.0
    lamp.omni_range = 12.0
    dungeon_entrance.add_child(lamp)
    add_child(dungeon_entrance)


func _enter_dungeon() -> void:
    if dungeon_active:
        return
    dungeon_return_position = player.global_position
    # Each new delve receives its own seed; the saved seed identifies the current delve.
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    dungeon_seed = int(rng.randi())
    _save_game()
    _build_randomized_dungeon(dungeon_seed)
    dungeon_active = true
    player.global_position = Vector3(0.0, 0.3, 1000.0)
    player.velocity = Vector3.ZERO
    objective_label.text = "The Shifting Hollow • find the violet exit"
    _open_dialogue("The Shifting Hollow", "The passage folds behind you. Its chambers rearrange with every descent. Follow the violet lights; the exit will return you to the same wilderness path.", 2)


func _build_randomized_dungeon(seed_value: int) -> void:
    if dungeon_root != null and is_instance_valid(dungeon_root):
        dungeon_root.queue_free()
    dungeon_root = Node3D.new()
    dungeon_root.name = "GeneratedDungeon"
    dungeon_root.position = Vector3(0.0, 0.0, 1000.0)
    add_child(dungeon_root)
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var floor_body := StaticBody3D.new()
    var floor_mesh := MeshInstance3D.new()
    var floor_plane := PlaneMesh.new()
    floor_plane.size = DUNGEON_FLOOR_SIZE
    floor_mesh.mesh = floor_plane
    floor_mesh.material_override = _stone_material(Color(0.075, 0.055, 0.1), 0.2)
    floor_body.add_child(floor_mesh)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(DUNGEON_FLOOR_SIZE.x, 0.4, DUNGEON_FLOOR_SIZE.y)
    collision.shape = shape
    collision.position.y = -0.2
    floor_body.add_child(collision)
    dungeon_root.add_child(floor_body)
    # Procedurally place 6-9 chambers along a winding corridor, with side rooms.
    var chamber_count := rng.randi_range(6, 9)
    for i in range(chamber_count):
        var z := -26.0 + float(i) * 7.0
        var x := rng.randf_range(-11.0, 11.0) if i > 0 else 0.0
        var room := Node3D.new()
        room.name = "Chamber_%02d" % i
        room.position = Vector3(x, 0.0, z)
        var marker := MeshInstance3D.new()
        var marker_mesh := CylinderMesh.new()
        marker_mesh.top_radius = 2.0
        marker_mesh.bottom_radius = 3.2
        marker_mesh.height = 0.25
        marker.mesh = marker_mesh
        marker.position.y = 0.13
        marker.material_override = _stone_material(Color(0.14, 0.095, 0.2), 0.3)
        room.add_child(marker)
        var crystal := MeshInstance3D.new()
        var crystal_mesh := PrismMesh.new()
        crystal_mesh.size = Vector3(0.75, rng.randf_range(1.5, 3.0), 0.75)
        crystal.mesh = crystal_mesh
        crystal.position = Vector3(rng.randf_range(-2.0, 2.0), crystal_mesh.size.y * 0.5, rng.randf_range(-2.0, 2.0))
        crystal.material_override = _glow_material([Color(0.55,0.18,0.85),Color(0.18,0.55,0.9),Color(0.9,0.3,0.48)][rng.randi_range(0,2)])
        room.add_child(crystal)
        var light := OmniLight3D.new()
        light.position.y = 2.2
        light.light_color = Color(0.42, 0.18, 0.8)
        light.light_energy = 1.0
        light.omni_range = 7.0
        room.add_child(light)
        dungeon_root.add_child(room)
        if i > 0:
            var wall := MeshInstance3D.new()
            var wall_mesh := BoxMesh.new()
            wall_mesh.size = Vector3(rng.randf_range(2.0, 5.0), rng.randf_range(2.0, 4.5), 0.8)
            wall.mesh = wall_mesh
            wall.position = Vector3(x + rng.randf_range(-5.0, 5.0), wall_mesh.size.y * 0.5, z - 3.0)
            wall.material_override = _stone_material(Color(0.12, 0.075, 0.16), 0.3)
            dungeon_root.add_child(wall)
    dungeon_exit = Node3D.new()
    dungeon_exit.name = "DungeonExit"
    dungeon_exit.position = Vector3(rng.randf_range(-4.0, 4.0), 0.0, 22.0)
    var exit_crystal := MeshInstance3D.new()
    var exit_mesh := PrismMesh.new()
    exit_mesh.size = Vector3(2.0, 3.5, 2.0)
    exit_crystal.mesh = exit_mesh
    exit_crystal.position.y = 1.8
    exit_crystal.material_override = _glow_material(Color(0.72, 0.28, 1.0))
    dungeon_exit.add_child(exit_crystal)
    var exit_light := OmniLight3D.new()
    exit_light.position.y = 2.0
    exit_light.light_color = Color(0.72, 0.28, 1.0)
    exit_light.light_energy = 2.0
    exit_light.omni_range = 10.0
    dungeon_exit.add_child(exit_light)
    dungeon_root.add_child(dungeon_exit)


func _leave_dungeon() -> void:
    dungeon_active = false
    if dungeon_root != null and is_instance_valid(dungeon_root):
        dungeon_root.queue_free()
    dungeon_root = null
    dungeon_exit = null
    player.global_position = dungeon_return_position
    player.velocity = Vector3.ZERO
    objective_label.text = "The wilderness remembers your path."
    _save_game()
    _open_dialogue("Back to the Realm", "The shifting passage settles behind you. The roads, landmarks, and sanctuary remain as you left them.", 2)

func _build_starting_town() -> void:
    _add_platform(Vector3(0, -0.04, 10.0), Vector3(25.0, 0.18, 36.0), Color(0.105, 0.09, 0.13))
    for side in [-1.0, 1.0]:
        for i in range(3):
            var building := Node3D.new()
            building.position = Vector3(side * (7.2 + float(i % 2) * 1.2), 0.0, 18.0 - float(i) * 7.0)
            if not _try_replace_visual_with_model(building, "res://assets/models/architecture/fantasy cottage 3d model.glb", Vector3(1.1, 1.1, 1.1)):
                var walls := MeshInstance3D.new()
                var wall_mesh := BoxMesh.new()
                wall_mesh.size = Vector3(4.0, 3.2, 4.0)
                walls.mesh = wall_mesh
                walls.position.y = 1.6
                walls.material_override = _stone_material(Color(0.18, 0.14, 0.2), 0.12)
                building.add_child(walls)
                var roof := MeshInstance3D.new()
                var roof_mesh := PrismMesh.new()
                roof_mesh.size = Vector3(4.8, 2.0, 4.8)
                roof.mesh = roof_mesh
                roof.position.y = 4.0
                roof.material_override = _stone_material(Color(0.12, 0.075, 0.16), 0.1)
                building.add_child(roof)
            add_child(building)
            var lamp := OmniLight3D.new()
            lamp.position = building.position + Vector3(-side, 1.8, -2.1)
            lamp.light_color = Color(0.95, 0.45, 0.19)
            lamp.light_energy = 0.7
            lamp.omni_range = 4.5
            add_child(lamp)
    for i in range(5):
        var tree := Node3D.new()
        tree.position = Vector3(-11.0 + float(i) * 5.5, 0.0, 26.0)
        if not _try_replace_visual_with_model(tree, "res://assets/models/environment/haunted blackwood tree 3d model.glb", Vector3.ONE):
            var trunk := MeshInstance3D.new()
            var trunk_mesh := CylinderMesh.new()
            trunk_mesh.top_radius = 0.25
            trunk_mesh.bottom_radius = 0.6
            trunk_mesh.height = 5.0
            trunk.mesh = trunk_mesh
            trunk.position.y = 2.5
            trunk.material_override = _stone_material(Color(0.13, 0.105, 0.14), 0.1)
            tree.add_child(trunk)
        add_child(tree)

func _spawn_intro_enemies() -> void:
    for enemy in intro_enemies:
        if is_instance_valid(enemy): enemy.queue_free()
    intro_enemies.clear()
    intro_enemy_hp.clear()
    var positions := [Vector3(-2.1, 0.0, -1.5), Vector3(2.2, 0.0, -2.0), Vector3(0.0, 0.0, 1.0)]
    var names := ["Riftbound Raider", "Sigil-Thief", "Veil Stalker"]
    for i in range(positions.size()):
        var enemy := Node3D.new()
        enemy.name = names[i]
        enemy.position = positions[i]
        var body := MeshInstance3D.new()
        var mesh := CapsuleMesh.new()
        mesh.radius = 0.42
        mesh.height = 1.9
        body.mesh = mesh
        body.position.y = 0.95
        body.material_override = _stone_material(Color(0.11, 0.07, 0.16), 0.6)
        enemy.add_child(body)
        var core := MeshInstance3D.new()
        var core_mesh := SphereMesh.new()
        core_mesh.radius = 0.22
        core_mesh.height = 0.44
        core.mesh = core_mesh
        core.position = Vector3(0, 1.2, -0.38)
        core.material_override = _glow_material(Color(0.82, 0.12, 0.34))
        enemy.add_child(core)
        _try_replace_visual_with_model(enemy, "res://assets/models/creatures/shadow+beast+3d+model.glb", Vector3(0.85, 0.85, 0.85))
        add_child(enemy)
        intro_enemies.append(enemy)
        intro_enemy_hp[enemy.get_instance_id()] = 3
    intro_battle_active = true
    objective_label.text = "Quest: Help Mathias survive the ambush (%d attackers)" % intro_enemies.size()

func _nearest_intro_enemy(max_distance: float) -> Node3D:
    var nearest: Node3D = null
    var best := max_distance
    for enemy in intro_enemies:
        if is_instance_valid(enemy):
            var distance := player.global_position.distance_to(enemy.global_position)
            if distance < best:
                best = distance
                nearest = enemy
    return nearest

func _damage_intro_enemy(enemy: Node3D, damage: int) -> void:
    if not is_instance_valid(enemy): return
    var id := enemy.get_instance_id()
    var hp := int(intro_enemy_hp.get(id, 0)) - damage
    if hp <= 0:
        intro_enemy_hp.erase(id)
        intro_enemies.erase(enemy)
        enemy.queue_free()
        if intro_enemies.is_empty():
            intro_battle_active = false
            intro_battle_finished = true
            objective_label.text = "Quest: Speak with Mathias"
            prompt_label.text = "The attackers are defeated. Press E near Mathias."
            _open_dialogue("Mathias", "By the old stars—you held them off! Come closer, apprentice. What I tell you next will change the way you see this Realm.", 0)
    else:
        intro_enemy_hp[id] = hp

func _update_intro_battle(delta: float) -> void:
    intro_enemy_attack_timer -= delta
    for enemy in intro_enemies:
        if not is_instance_valid(enemy): continue
        var toward := player.global_position - enemy.global_position
        toward.y = 0.0
        if toward.length() > 1.8:
            enemy.position += toward.normalized() * 1.05 * delta
            enemy.look_at(Vector3(player.global_position.x, enemy.global_position.y, player.global_position.z), Vector3.UP)
    if intro_enemy_attack_timer <= 0.0 and not intro_enemies.is_empty():
        intro_enemy_attack_timer = 1.4
        if _nearest_intro_enemy(2.2) != null:
            player_hp = maxi(1, player_hp - 1)
            status_label.text = player_name + "  |  HP " + str(player_hp) + "/5"
            prompt_label.text = "An attacker struck! Keep moving and fight back."

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
    npc.rotation.y = PI

    var robe := MeshInstance3D.new()
    var robe_mesh := CylinderMesh.new()
    robe_mesh.top_radius = 0.22
    robe_mesh.bottom_radius = 0.56
    robe_mesh.height = 1.8
    robe.mesh = robe_mesh
    robe.position.y = 0.92
    var robe_mat := _stone_material(Color(0.12, 0.075, 0.23), 0.24)
    robe_mat.roughness = 0.76
    robe.material_override = robe_mat
    npc.add_child(robe)

    var mantle := MeshInstance3D.new()
    var mantle_mesh := BoxMesh.new()
    mantle_mesh.size = Vector3(0.8, 0.82, 0.13)
    mantle.mesh = mantle_mesh
    mantle.position = Vector3(0, 1.15, 0.32)
    mantle.material_override = _stone_material(Color(0.075, 0.05, 0.12), 0.12)
    npc.add_child(mantle)

    var robe_trim := MeshInstance3D.new()
    var trim_mesh := TorusMesh.new()
    trim_mesh.inner_radius = 0.47
    trim_mesh.outer_radius = 0.51
    robe_trim.mesh = trim_mesh
    robe_trim.position.y = 0.38
    robe_trim.material_override = _glow_material(Color(0.69, 0.44, 0.95))
    npc.add_child(robe_trim)

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

    var beard := MeshInstance3D.new()
    var beard_mesh := CylinderMesh.new()
    beard_mesh.top_radius = 0.035
    beard_mesh.bottom_radius = 0.16
    beard_mesh.height = 0.42
    beard.mesh = beard_mesh
    beard.position = Vector3(0, 1.68, -0.16)
    var beard_mat := StandardMaterial3D.new()
    beard_mat.albedo_color = Color(0.67, 0.65, 0.76)
    beard_mat.roughness = 0.95
    beard.material_override = beard_mat
    npc.add_child(beard)

    var hat_brim := MeshInstance3D.new()
    var brim_mesh := CylinderMesh.new()
    brim_mesh.top_radius = 0.43
    brim_mesh.bottom_radius = 0.48
    brim_mesh.height = 0.11
    hat_brim.mesh = brim_mesh
    hat_brim.position.y = 2.22
    hat_brim.material_override = _stone_material(Color(0.18, 0.09, 0.29), 0.18)
    npc.add_child(hat_brim)

    var hat := MeshInstance3D.new()
    var hat_mesh := CylinderMesh.new()
    hat_mesh.top_radius = 0.02
    hat_mesh.bottom_radius = 0.39
    hat_mesh.height = 0.76
    hat.mesh = hat_mesh
    hat.position.y = 2.58
    hat.rotation_degrees.z = -9.0
    hat.material_override = _stone_material(Color(0.27, 0.105, 0.42), 0.18)
    npc.add_child(hat)

    var hat_band := MeshInstance3D.new()
    var band_mesh := TorusMesh.new()
    band_mesh.inner_radius = 0.36
    band_mesh.outer_radius = 0.39
    hat_band.mesh = band_mesh
    hat_band.position.y = 2.31
    hat_band.material_override = _glow_material(Color(0.83, 0.61, 0.25))
    npc.add_child(hat_band)

    var staff := MeshInstance3D.new()
    var staff_mesh := CylinderMesh.new()
    staff_mesh.top_radius = 0.035
    staff_mesh.bottom_radius = 0.06
    staff_mesh.height = 2.0
    staff.mesh = staff_mesh
    staff.position = Vector3(0.7, 1.0, 0)
    staff.rotation_degrees.z = -8
    staff.material_override = _stone_material(Color(0.42, 0.24, 0.15), 0.08)
    npc.add_child(staff)

    var staff_crystal := MeshInstance3D.new()
    var crystal_mesh := PrismMesh.new()
    crystal_mesh.size = Vector3(0.28, 0.46, 0.28)
    staff_crystal.mesh = crystal_mesh
    staff_crystal.position = Vector3(0.78, 2.05, 0)
    staff_crystal.material_override = _glow_material(Color(0.69, 0.4, 1.0))
    npc.add_child(staff_crystal)
    animated_crystals.append(staff_crystal)
    crystal_home_y[staff_crystal.get_instance_id()] = staff_crystal.position.y

    var staff_light := OmniLight3D.new()
    staff_light.position = Vector3(0.78, 2.05, 0)
    staff_light.light_color = Color(0.58, 0.3, 1.0)
    staff_light.light_energy = 0.8
    staff_light.omni_range = 4.0
    npc.add_child(staff_light)
    # Use the available armored character model for Mathias.
    _try_replace_visual_with_model(npc, "res://assets/models/characters/dark armored knight 3d model.glb", Vector3.ONE)
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


func _try_replace_visual_with_model(parent: Node3D, model_path: String, model_scale: Vector3 = Vector3.ONE, model_position: Vector3 = Vector3.ZERO) -> bool:
    # Tripo/Blender GLB models are optional. If the file is absent or invalid,
    # the procedural model remains visible so the browser build always works.
    if not ResourceLoader.exists(model_path):
        return false

    # Some repository assets may be Git LFS pointer text rather than actual GLB
    # binaries (for example, when LFS objects were not included in a checkout).
    # Validate the GLB magic header before asking Godot to load it, preventing
    # noisy engine errors and allowing the procedural fallback to remain visible.
    var model_file := FileAccess.open(model_path, FileAccess.READ)
    if model_file == null:
        return false
    var glb_header: String = model_file.get_buffer(4).get_string_from_ascii()
    model_file.close()
    if glb_header != "glTF":
        return false

    var packed_scene := load(model_path) as PackedScene
    if packed_scene == null:
        push_warning("Optional model could not be loaded as a PackedScene: " + model_path)
        return false
    var instance := packed_scene.instantiate()
    var model_root := instance as Node3D
    if model_root == null:
        instance.queue_free()
        push_warning("Optional model root must be Node3D: " + model_path)
        return false
    for child in parent.get_children():
        if child is VisualInstance3D:
            child.visible = false
    model_root.name = "ImportedModel"
    model_root.position = model_position
    model_root.scale = model_scale
    parent.add_child(model_root)
    return true

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
    animated_crystals.append(crystal)
    crystal_home_y[crystal.get_instance_id()] = crystal.position.y
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

func _add_haunted_trees() -> void:
    for i in range(7):
        var z := 4.0 - float(i) * 5.3
        var height := 4.6 + float(i % 3) * 0.8
        _add_haunted_tree(Vector3(-13.0 - float(i % 2) * 2.0, 0, z), height)
        _add_haunted_tree(Vector3(13.0 + float(i % 2) * 2.0, 0, z - 1.4), height + 0.4)
    for side in [-1.0, 1.0]:
        for z in [-8.0, -20.0, -30.0]:
            var wisp := MeshInstance3D.new()
            var wisp_mesh := SphereMesh.new()
            wisp_mesh.radius = 0.16
            wisp_mesh.height = 0.32
            wisp.mesh = wisp_mesh
            wisp.position = Vector3(side * 10.8, 1.35, z)
            wisp.material_override = _glow_material(Color(0.38, 0.78, 0.31))
            add_child(wisp)
            var wisp_light := OmniLight3D.new()
            wisp_light.position = wisp.position
            wisp_light.light_color = Color(0.36, 0.7, 0.25)
            wisp_light.light_energy = 0.65
            wisp_light.omni_range = 4.5
            add_child(wisp_light)

func _add_haunted_tree(pos: Vector3, height: float) -> void:
    var tree := Node3D.new()
    tree.position = pos
    var trunk := MeshInstance3D.new()
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.12
    trunk_mesh.bottom_radius = 0.34
    trunk_mesh.height = height
    trunk.mesh = trunk_mesh
    trunk.position.y = height * 0.5
    trunk.rotation_degrees.z = sin(pos.z * 0.4) * 9.0
    trunk.material_override = _stone_material(Color(0.045, 0.035, 0.055), 0.05)
    tree.add_child(trunk)
    for branch_index in range(3):
        var branch := MeshInstance3D.new()
        var branch_mesh := CylinderMesh.new()
        branch_mesh.top_radius = 0.025
        branch_mesh.bottom_radius = 0.12
        branch_mesh.height = height * 0.42
        branch.mesh = branch_mesh
        var side := -1.0 if branch_index % 2 == 0 else 1.0
        branch.position = Vector3(side * (0.42 + float(branch_index) * 0.12), height * (0.42 + float(branch_index) * 0.13), 0)
        branch.rotation_degrees.z = -side * (34.0 + float(branch_index) * 12.0)
        branch.material_override = trunk.material_override
        tree.add_child(branch)
    var crown := MeshInstance3D.new()
    var crown_mesh := SphereMesh.new()
    crown_mesh.radius = 1.0
    crown_mesh.height = 2.0
    crown.mesh = crown_mesh
    crown.scale = Vector3(1.15, 1.45, 0.92)
    crown.position = Vector3(0, height * 0.83, 0)
    var crown_mat := StandardMaterial3D.new()
    crown_mat.albedo_color = Color(0.025, 0.055, 0.045)
    crown_mat.roughness = 1.0
    crown.material_override = crown_mat
    tree.add_child(crown)
    _try_replace_visual_with_model(tree, "res://assets/models/environment/haunted blackwood tree 3d model.glb", Vector3.ONE * (height / 3.0))
    add_child(tree)

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 0.2, 22.0)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.8
    collision.shape = capsule
    collision.position.y = 0.9
    player.add_child(collision)
    player_visual_root = Node3D.new()
    player.add_child(player_visual_root)

    # Layered apprentice robes instead of the original plain capsule placeholder.
    var robe := MeshInstance3D.new()
    var robe_mesh := CylinderMesh.new()
    robe_mesh.top_radius = 0.24
    robe_mesh.bottom_radius = 0.58
    robe_mesh.height = 1.42
    robe.mesh = robe_mesh
    robe.position.y = 0.78
    var robe_mat := _stone_material(Color(0.19, 0.105, 0.34), 0.22)
    robe_mat.roughness = 0.72
    robe.material_override = robe_mat
    player_visual_root.add_child(robe)

    var robe_trim := MeshInstance3D.new()
    var trim_mesh := TorusMesh.new()
    trim_mesh.inner_radius = 0.47
    trim_mesh.outer_radius = 0.51
    robe_trim.mesh = trim_mesh
    robe_trim.position.y = 0.37
    robe_trim.material_override = _glow_material(Color(0.67, 0.39, 0.95))
    player_visual_root.add_child(robe_trim)

    var mantle := MeshInstance3D.new()
    var mantle_mesh := BoxMesh.new()
    mantle_mesh.size = Vector3(0.78, 0.9, 0.12)
    mantle.mesh = mantle_mesh
    mantle.position = Vector3(0, 1.18, 0.31)
    mantle.material_override = _stone_material(Color(0.10, 0.07, 0.18), 0.12)
    player_visual_root.add_child(mantle)

    var belt := MeshInstance3D.new()
    var belt_mesh := TorusMesh.new()
    belt_mesh.inner_radius = 0.31
    belt_mesh.outer_radius = 0.35
    belt.mesh = belt_mesh
    belt.position.y = 0.96
    belt.material_override = _glow_material(Color(0.83, 0.58, 0.22))
    player_visual_root.add_child(belt)

    var head := MeshInstance3D.new()
    var head_shape := SphereMesh.new()
    head_shape.radius = 0.25
    head_shape.height = 0.5
    head.mesh = head_shape
    head.position.y = 1.73
    var head_mat := StandardMaterial3D.new()
    head_mat.albedo_color = Color(0.72, 0.55, 0.43)
    head.material_override = head_mat
    player_visual_root.add_child(head)

    var hat_brim := MeshInstance3D.new()
    var brim_mesh := CylinderMesh.new()
    brim_mesh.top_radius = 0.38
    brim_mesh.bottom_radius = 0.42
    brim_mesh.height = 0.1
    hat_brim.mesh = brim_mesh
    hat_brim.position.y = 1.99
    hat_brim.material_override = _stone_material(Color(0.13, 0.07, 0.22), 0.18)
    player_visual_root.add_child(hat_brim)

    var hat := MeshInstance3D.new()
    var hat_mesh := CylinderMesh.new()
    hat_mesh.top_radius = 0.015
    hat_mesh.bottom_radius = 0.32
    hat_mesh.height = 0.72
    hat.mesh = hat_mesh
    hat.position.y = 2.38
    hat.rotation_degrees.z = -7.0
    hat.material_override = _stone_material(Color(0.24, 0.12, 0.39), 0.16)
    player_visual_root.add_child(hat)

    var hat_band := MeshInstance3D.new()
    var band_mesh := TorusMesh.new()
    band_mesh.inner_radius = 0.29
    band_mesh.outer_radius = 0.32
    hat_band.mesh = band_mesh
    hat_band.position.y = 2.08
    hat_band.material_override = _glow_material(Color(0.86, 0.62, 0.24))
    player_visual_root.add_child(hat_band)

    var staff := MeshInstance3D.new()
    var staff_mesh := CylinderMesh.new()
    staff_mesh.top_radius = 0.035
    staff_mesh.bottom_radius = 0.055
    staff_mesh.height = 1.9
    staff.mesh = staff_mesh
    staff.position = Vector3(0.65, 0.9, -0.05)
    staff.rotation_degrees.z = -7.0
    staff.material_override = _stone_material(Color(0.34, 0.19, 0.12), 0.12)
    player_visual_root.add_child(staff)

    var staff_crystal := MeshInstance3D.new()
    var crystal_mesh := PrismMesh.new()
    crystal_mesh.size = Vector3(0.3, 0.48, 0.3)
    staff_crystal.mesh = crystal_mesh
    staff_crystal.position = Vector3(0.77, 1.92, -0.05)
    staff_crystal.rotation_degrees.z = 18.0
    staff_crystal.material_override = _glow_material(Color(0.63, 0.29, 1.0))
    player_visual_root.add_child(staff_crystal)
    animated_crystals.append(staff_crystal)
    crystal_home_y[staff_crystal.get_instance_id()] = staff_crystal.position.y

    var crystal_light := OmniLight3D.new()
    crystal_light.position = Vector3(0.77, 1.92, -0.05)
    crystal_light.light_color = Color(0.54, 0.25, 1.0)
    crystal_light.light_energy = 0.6
    crystal_light.omni_range = 3.0
    player_visual_root.add_child(crystal_light)
    _apply_selected_character_model()

    # Keep camera yaw independent from the character's facing direction.
    # This avoids WASD turning the camera and feeding back into movement.
    # Add the player before reading its global transform; unattached nodes do
    # not have a valid global transform yet.
    add_child(player)
    camera_pivot = Node3D.new()
    camera_pivot.top_level = true
    add_child(camera_pivot)
    # Set the global transform only after the pivot enters the scene tree.
    camera_pivot.global_position = player.global_position + Vector3(0, 1.45, 0)
    camera = Camera3D.new()
    camera.position = Vector3(0, 0.2, 5.4)
    camera.rotation.x = -0.18
    camera.current = true
    camera_pivot.add_child(camera)

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
    menu_panel.position = Vector2(-300, -300)
    menu_panel.size = Vector2(600, 600)
    menu_panel.custom_minimum_size = Vector2(600, 600)
    root.add_child(menu_panel)
    var menu_box := VBoxContainer.new()
    menu_box.add_theme_constant_override("separation", 14)
    menu_panel.add_child(menu_box)
    var title := Label.new()
    title.text = "THE WIZARDS OF ARK"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    title.add_theme_color_override("font_color", Color(0.82, 0.63, 1.0))
    menu_box.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "A DARK FANTASY SAGA  •  THE SIGIL AWAKENS"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 15)
    menu_box.add_child(subtitle)
    var intro := Label.new()
    intro.text = "The old wards are failing. The Council is silent.\nCreate your wizard and enter the living legend of the Arcane Realm."
    intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    menu_box.add_child(intro)
    name_input = LineEdit.new()
    name_input.placeholder_text = "Enter your wizard's name"
    name_input.text = ""
    name_input.custom_minimum_size.y = 42
    menu_box.add_child(name_input)
    var character_label := Label.new()
    character_label.text = "CHOOSE YOUR WIZARD"
    character_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    menu_box.add_child(character_label)
    character_select = OptionButton.new()
    character_select.add_item("Wizard — Arcane Apprentice", 0)
    character_select.add_item("Wizardrobe — Veiled Wanderer", 1)
    character_select.item_selected.connect(_on_character_selected)
    menu_box.add_child(character_select)
    var settings_button := Button.new()
    settings_button.text = "SETTINGS ⚙"
    settings_button.pressed.connect(_toggle_settings)
    menu_box.add_child(settings_button)
    var start_button := Button.new()
    start_button.text = "BEGIN YOUR STORY"
    start_button.custom_minimum_size.y = 48
    start_button.pressed.connect(_on_start_pressed)
    menu_box.add_child(start_button)
    continue_button = Button.new()
    continue_button.text = "CONTINUE JOURNEY"
    continue_button.custom_minimum_size.y = 44
    continue_button.pressed.connect(_on_continue_pressed)
    menu_box.add_child(continue_button)
    var hint := Label.new()
    hint.text = "WASD move  •  Mouse look  •  Space jump  •  E interact  •  F / Q combat"
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
    objective_label = Label.new()
    objective_label.text = "Quest: Help Mathias survive the ambush"
    objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hud_box.add_child(objective_label)

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
    var dialogue_continue_button := Button.new()
    dialogue_continue_button.text = "Continue  [E]"
    dialogue_continue_button.pressed.connect(_advance_dialogue)
    dialog_box.add_child(dialogue_continue_button)
    settings_panel = PanelContainer.new()
    settings_panel.set_anchors_preset(Control.PRESET_CENTER)
    settings_panel.position = Vector2(-220, -150)
    settings_panel.size = Vector2(440, 300)
    settings_panel.custom_minimum_size = Vector2(440, 300)
    root.add_child(settings_panel)
    var settings_box := VBoxContainer.new()
    settings_box.add_theme_constant_override("separation", 12)
    settings_panel.add_child(settings_box)
    var settings_title := Label.new()
    settings_title.text = "REALM SETTINGS"
    settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    settings_title.add_theme_font_size_override("font_size", 23)
    settings_box.add_child(settings_title)
    var sens_label := Label.new()
    sens_label.text = "Mouse look sensitivity"
    settings_box.add_child(sens_label)
    mouse_sensitivity_slider = HSlider.new()
    mouse_sensitivity_slider.min_value = 0.001
    mouse_sensitivity_slider.max_value = 0.006
    mouse_sensitivity_slider.step = 0.0005
    mouse_sensitivity_slider.value = mouse_sensitivity
    mouse_sensitivity_slider.value_changed.connect(func(value: float): mouse_sensitivity = value)
    settings_box.add_child(mouse_sensitivity_slider)
    var invert_toggle := CheckButton.new()
    invert_toggle.text = "Invert vertical camera"
    invert_toggle.toggled.connect(func(enabled: bool): invert_y = enabled)
    settings_box.add_child(invert_toggle)
    var settings_close := Button.new()
    settings_close.text = "BACK TO CHARACTER CREATION"
    settings_close.pressed.connect(_toggle_settings)
    settings_box.add_child(settings_close)
    settings_panel.hide()
    hud_panel.hide()
    dialogue_panel.hide()
    continue_button.hide()

func _show_menu() -> void:
    menu_panel.show()
    settings_panel.hide()
    hud_panel.hide()
    dialogue_panel.hide()
    started = false

func _on_character_selected(index: int) -> void:
    selected_character = "Wizardrobe" if index == 1 else "Wizard"
    _apply_selected_character_model()

func _apply_selected_character_model() -> void:
    if player_visual_root == null: return
    for child in player_visual_root.get_children():
        if child is VisualInstance3D: child.visible = true
        elif child is Node3D and child.name == "ImportedModel": child.queue_free()
    var model_path := "res://assets/models/characters/fantasy wizard 3d model.glb"
    if selected_character == "Wizardrobe": model_path = "res://assets/models/characters/wizard robe 3d model.glb"
    _try_replace_visual_with_model(player_visual_root, model_path, Vector3.ONE)

func _toggle_settings() -> void:
    if settings_panel.visible:
        settings_panel.hide()
        menu_panel.show()
    else:
        menu_panel.hide()
        settings_panel.show()

func _on_start_pressed() -> void:
    _reset_new_game()
    player_name = name_input.text.strip_edges()
    if player_name.is_empty():
        player_name = "Apprentice"
    status_label.text = player_name + "  |  HP 5/5"
    objective_label.text = "Quest: Help Mathias survive the ambush"
    _save_game()
    menu_panel.hide()
    settings_panel.hide()
    hud_panel.show()
    started = true
    intro_battle_active = true
    intro_battle_finished = false
    _spawn_intro_enemies()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    prompt_label.text = "Mathias is under attack! Use F nearby or Q from range."

func _reset_new_game() -> void:
    for shrine in rune_shrines:
        if is_instance_valid(shrine):
            shrine.queue_free()
    rune_shrines.clear()
    collected_rune_names.clear()
    collected_runes = 0
    quest_complete = false
    trial_complete = false
    trial_started = false
    player_hp = 5
    player.global_position = Vector3(0, 0.2, 22.0)
    player.velocity = Vector3.ZERO
    intro_battle_active = false
    intro_battle_finished = false
    for enemy in intro_enemies:
        if is_instance_valid(enemy): enemy.queue_free()
    intro_enemies.clear()
    intro_enemy_hp.clear()
    _create_rune_shrine(Vector3(-5.8, 0.0, -9.0), "Dawn", Color(1.0, 0.63, 0.24))
    _create_rune_shrine(Vector3(5.8, 0.0, -9.0), "Dusk", Color(0.34, 0.62, 1.0))
    _create_rune_shrine(Vector3(0.0, 0.0, -15.0), "Heart", Color(0.74, 0.35, 1.0))
    gate_seal.show()
    gate_portal.hide()

func _on_continue_pressed() -> void:
    if not save_exists:
        return
    menu_panel.hide()
    hud_panel.show()
    started = true
    dialogue_open = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if trial_complete or quest_complete:
        player.global_position = Vector3(0, 0.3, -15.0)
    else:
        player.global_position = Vector3(0, 0.2, 5.0)
    player.velocity = Vector3.ZERO
    status_label.text = player_name + "  |  HP " + str(player_hp) + "/5"

func _load_game() -> void:
    var path := "user://arcane_realm_save.json"
    if not FileAccess.file_exists(path):
        save_exists = false
        return
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        save_exists = false
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        save_exists = false
        return
    world_seed = int(parsed.get("world_seed", world_seed))
    dungeon_seed = int(parsed.get("dungeon_seed", 0))
    player_name = str(parsed.get("player_name", "Apprentice"))
    selected_character = str(parsed.get("selected_character", "Wizard"))
    if is_instance_valid(character_select): character_select.select(1 if selected_character == "Wizardrobe" else 0)
    _apply_selected_character_model()
    collected_rune_names.clear()
    var saved_names = parsed.get("collected_runes", [])
    if saved_names is Array:
        for saved_name in saved_names:
            collected_rune_names.append(str(saved_name))
    collected_runes = collected_rune_names.size()
    for shrine in rune_shrines.duplicate():
        var rune_name: String = str(shrine.name).replace(" Sigil", "")
        if collected_rune_names.has(rune_name):
            rune_shrines.erase(shrine)
            shrine.queue_free()
    quest_complete = bool(parsed.get("quest_complete", collected_runes >= 3))
    trial_complete = bool(parsed.get("trial_complete", false))
    if quest_complete:
        gate_seal.hide()
        gate_portal.show()
    save_exists = true
    if is_instance_valid(status_label):
        status_label.text = player_name + "  |  HP " + str(player_hp) + "/5"
        if trial_complete:
            objective_label.text = "First Trial complete: The gate is yours"
        elif quest_complete:
            objective_label.text = "Quest complete: Enter the awakened gate"
        elif collected_runes > 0:
            objective_label.text = "Quest: Recover the sigils (%d/3)" % collected_runes
        else:
            objective_label.text = "Quest: Speak with Mathias"
    if is_instance_valid(continue_button):
        continue_button.show()

func _save_game() -> void:
    var data := {
        "world_seed": world_seed,
        "dungeon_seed": dungeon_seed,
        "player_name": player_name,
        "selected_character": selected_character,
        "collected_runes": collected_rune_names,
        "quest_complete": quest_complete,
        "trial_complete": trial_complete
    }
    var file := FileAccess.open("user://arcane_realm_save.json", FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(data))
        file.close()
        save_exists = true
        if is_instance_valid(continue_button):
            continue_button.show()

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
        var mouse_delta_y: float = float(event.relative.y)
        if invert_y:
            mouse_delta_y = -mouse_delta_y
        pitch = clamp(pitch - mouse_delta_y * mouse_sensitivity, -0.55, 0.28)
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
    if player != null and camera_pivot != null:
        camera_pivot.global_position = player.global_position + Vector3(0, 1.45, 0)
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
    if intro_battle_active:
        _update_intro_battle(delta)
        prompt_label.text = "AMBUSH: F staff strike  •  Q arcane bolt  •  defeat the attackers"
        return
    if trial_started:
        _update_guardian(delta)
        prompt_label.text = "F: staff strike  •  Q: arcane bolt  •  keep moving!"
        return

    var nearest_rune_distance := 999.0
    for shrine in rune_shrines:
        nearest_rune_distance = min(nearest_rune_distance, player.global_position.distance_to(shrine.global_position))
    var mathias_distance := player.global_position.distance_to(interact_target.global_position)
    var gate_distance := player.global_position.distance_to(Vector3(0, 0, -19))
    if intro_battle_finished and mathias_distance < 4.5 and (mathias_distance <= nearest_rune_distance or story_step < 2):
        prompt_label.text = "Press E to speak with Mathias"
    elif nearest_rune_distance < 3.6:
        prompt_label.text = "Press E to claim the " + _nearest_rune_name() + " Sigil"
    elif gate_distance < 5.5:
        prompt_label.text = "Press E to enter the awakened gate" if quest_complete else "The gate is sealed • recover all 3 sigils"
    elif dungeon_entrance != null and player.global_position.distance_to(dungeon_entrance.global_position) < 5.0:
        prompt_label.text = "Press E to enter the shifting dungeon"
    elif dungeon_active and dungeon_exit != null and player.global_position.distance_to(dungeon_exit.global_position) < 4.5:
        prompt_label.text = "Press E to leave the dungeon"
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
    if dungeon_active:
        if dungeon_exit != null and player.global_position.distance_to(dungeon_exit.global_position) < 4.5:
            _leave_dungeon()
        return
    if dungeon_entrance != null and player.global_position.distance_to(dungeon_entrance.global_position) < 5.0:
        _enter_dungeon()
        return
    var mathias_distance := player.global_position.distance_to(interact_target.global_position)
    var nearest_shrine: Node3D = null
    var nearest_distance := 999.0
    for shrine in rune_shrines:
        var distance := player.global_position.distance_to(shrine.global_position)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest_shrine = shrine
    if intro_battle_finished and mathias_distance < 4.5 and (mathias_distance <= nearest_distance or story_step < 2):
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
    var rune_name: String = str(shrine.name).replace(" Sigil", "")
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
    _save_game()

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
    animated_crystals.append(chest)
    crystal_home_y[chest.get_instance_id()] = chest.position.y
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
    _try_replace_visual_with_model(guardian, "res://assets/models/creatures/dark+fantasy+boss+3d+model.glb", Vector3.ONE)
    add_child(guardian)

func _staff_attack() -> void:
    if staff_cooldown > 0.0: return
    if intro_battle_active:
        var target := _nearest_intro_enemy(3.2)
        if target == null:
            prompt_label.text = "Move closer to an attacker for a staff strike."
            return
        staff_cooldown = 0.48
        _damage_intro_enemy(target, 1)
        return
    if not trial_started or guardian == null: return
    if player.global_position.distance_to(guardian.global_position) > 3.2:
        prompt_label.text = "Move closer for a staff strike!"
        return
    staff_cooldown = 0.48
    guardian_hp -= 1
    _show_guardian_hit(Color(0.88, 0.5, 1.0))
    objective_label.text = "Guardian: %d/%d HP  •  Your HP: %d/5" % [maxi(0, guardian_hp), guardian_max_hp, player_hp]
    if guardian_hp <= 0:
        _defeat_guardian()

func _launch_bolt_at(target: Node3D) -> void:
    var bolt := MeshInstance3D.new()
    var bolt_mesh := SphereMesh.new()
    bolt_mesh.radius = 0.22
    bolt_mesh.height = 0.44
    bolt.mesh = bolt_mesh
    bolt.position = player.global_position + Vector3(0, 1.35, 0)
    bolt.material_override = _glow_material(Color(0.36, 0.72, 1.0))
    add_child(bolt)
    var tween := create_tween()
    tween.tween_property(bolt, "global_position", target.global_position + Vector3(0, 1.0, 0), 0.2)
    tween.finished.connect(func():
        if is_instance_valid(bolt): bolt.queue_free()
    )

func _cast_arcane_bolt() -> void:
    if spell_cooldown > 0.0: return
    if intro_battle_active:
        var target := _nearest_intro_enemy(16.0)
        if target == null:
            prompt_label.text = "No attacker is within arcane-bolt range."
            return
        spell_cooldown = 0.85
        _launch_bolt_at(target)
        _damage_intro_enemy(target, 2)
        return
    if not trial_started or guardian == null: return
    if player.global_position.distance_to(guardian.global_position) > 16.0:
        prompt_label.text = "The guardian is beyond your spell's reach."
        return
    spell_cooldown = 0.85
    _launch_bolt_at(guardian)
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
    _save_game()
    player.global_position = Vector3(0, 0.3, -15.0)
    player.velocity = Vector3.ZERO
    _open_dialogue("Guardian Defeated", "The guardian's core fractures into harmless light. The stolen sigil-energy returns to the sanctuary, and the old gate recognizes you as its keeper. This is the first victory of many, " + player_name + ".", 3)

func _interact_with_mathias() -> void:
    if not intro_battle_finished:
        _open_dialogue("Mathias", "Help me hold the line! Those riftbound things are tearing at the ward-stones!", 0)
        return
    if story_step <= 0:
        _open_dialogue("Mathias", "You came back for a stranger. That tells me more than a test of magic could. I am Mathias, Battle Mage sworn to the Council of Wizards, Warlocks & Witches. The town ward-stones bear the same blight that has been gnawing at our realms.", 0)
    elif story_step == 1:
        _open_dialogue("Mathias", "The first sigil is not a weapon. It is a promise: power must answer to purpose. Something has breached the old wards, and the sanctuary is only the first place it has touched.", 1)
    else:
        objective_label.text = "Quest: Recover the three ancient sigils"
        _open_dialogue("Mathias", "Dawn, Dusk, and Heart are the first three seals. Beyond the sanctuary, each realm has trials, guardians, riddles, and relics. The Council of Wizards, Warlocks & Witches keeps the old laws; champions earn standing through deeds, not titles alone. The Sigil Exchange, bounty ledgers, and riddle-keepers you may have heard of in the Discord are echoes of those ancient customs. Gather the three sigils and enter the First Trial so we can discover who is poisoning the wards.", 2)

func _open_dialogue(who: String, words: String, step: int) -> void:
    story_step = step
    dialogue_open = true
    dialogue_title.text = who
    dialogue_text.text = words
    dialogue_panel.show()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _advance_dialogue() -> void:
    if story_step == 0:
        _open_dialogue("Mathias", "The Realm is held together by more than stone and spell. The Council records our oaths; the Trials test our choices; and ancient riddles preserve truths too dangerous to write plainly. Even the Sigil Exchange began as a way to reward those who helped keep the realms alive. Now every seal is dimming at once.", 1)
    elif story_step == 1:
        _open_dialogue("Mathias", "Dawn, Dusk, and Heart. Three fragments hold the gate shut. Find their crystal shrines along the path and press E near each one to claim its sigil. Return to the arch when all three answer.", 2)
        objective_label.text = "Quest: Recover the three ancient sigils"
    else:
        dialogue_open = false
        dialogue_panel.hide()
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
