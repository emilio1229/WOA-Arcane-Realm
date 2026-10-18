extends Node3D

# Seeded, lightweight environment prototype. Visual meshes are temporary blockout assets.
const WORLD_SIZE := 34
const CELL := 2.0
var world_seed: int = 18427
var rng := RandomNumberGenerator.new()
var generated_root: Node3D
var player: CharacterBody3D
var camera: Camera3D
var seed_label: Label
var seed_input: LineEdit
var status_label: Label
var move_speed := 6.0

func _ready() -> void:
	_build_lighting()
	_build_player()
	_build_hud()
	generate_world(world_seed)

func _build_lighting() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.39, 0.62)
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = false
	add_child(sun)

func _mat(color: Color, roughness := 1.0, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.42
	capsule.height = 1.65
	var mesh := MeshInstance3D.new()
	mesh.mesh = capsule
	mesh.position.y = 0.9
	mesh.material_override = _mat(Color(0.42, 0.22, 0.68))
	player.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.65
	collision.shape = shape
	collision.position.y = 0.9
	player.add_child(collision)
	add_child(player)
	player.position = Vector3(0, 0, 8)
	camera = Camera3D.new()
	camera.name = "WorldCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 25.0
	camera.position = Vector3(15, 18, 20)
	camera.rotation_degrees = Vector3(-38, 36, 0)
	add_child(camera)
	camera.position = player.position + Vector3(14, 17, 18)
	camera.look_at(player.position, Vector3.UP)
	camera.current = true

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(290, 0)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	var title := Label.new()
	title.text = "WOA  •  WORLD FORGE"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	var help := Label.new()
	help.text = "WASD / arrows to explore"
	box.add_child(help)
	var row := HBoxContainer.new()
	box.add_child(row)
	seed_input = LineEdit.new()
	seed_input.text = str(world_seed)
	seed_input.placeholder_text = "World seed"
	seed_input.custom_minimum_size = Vector2(150, 36)
	row.add_child(seed_input)
	var regen := Button.new()
	regen.text = "Generate"
	regen.pressed.connect(_on_generate_pressed)
	row.add_child(regen)
	var randomize_button := Button.new()
	randomize_button.text = "Random seed"
	randomize_button.pressed.connect(_on_random_seed_pressed)
	box.add_child(randomize_button)
	status_label = Label.new()
	status_label.text = "Seeded world prototype"
	box.add_child(status_label)

func _on_generate_pressed() -> void:
	var parsed := seed_input.text.strip_edges().to_int()
	world_seed = parsed if seed_input.text.strip_edges().is_valid_int() else 18427
	generate_world(world_seed)

func _on_random_seed_pressed() -> void:
	world_seed = int(Time.get_unix_time_from_system()) % 2147483647
	seed_input.text = str(world_seed)
	generate_world(world_seed)

func generate_world(seed_value: int) -> void:
	world_seed = seed_value
	rng.seed = seed_value
	if is_instance_valid(generated_root):
		generated_root.queue_free()
	generated_root = Node3D.new()
	generated_root.name = "GeneratedEnvironment"
	add_child(generated_root)
	_make_ground()
	_make_stream()
	_make_path()
	_make_landmark()
	_scatter_forest()
	_scatter_rocks_and_crystals()
	_make_ruins()
	if is_instance_valid(status_label):
		status_label.text = "Seed %d  •  meadow / forest / stream / ruins" % world_seed

func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, scale_value := Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.scale = scale_value
	parent.add_child(instance)
	return instance

func _make_ground() -> void:
	var grass := _mat(Color(0.17, 0.29, 0.19))
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(WORLD_SIZE * CELL, WORLD_SIZE * CELL)
	_add_mesh(generated_root, floor_mesh, grass, Vector3.ZERO)
	# Irregular patches make biome boundaries readable even in the blockout stage.
	for i in range(58):
		var patch := PlaneMesh.new()
		patch.size = Vector2(rng.randf_range(2.0, 6.0), rng.randf_range(2.0, 5.0))
		var color := [Color(0.20,0.32,0.20), Color(0.24,0.31,0.18), Color(0.14,0.25,0.18)][rng.randi_range(0,2)]
		_add_mesh(generated_root, patch, _mat(color), Vector3(rng.randf_range(-30,30),0.012,rng.randf_range(-30,30)), Vector3.ONE)
	for x in range(-17, 18):
		for z in range(-17, 18):
			if (x * 7 + z * 13) % 4 == 0:
				continue

func _make_stream() -> void:
	var water := _mat(Color(0.12, 0.31, 0.42, 0.86), 0.25, 0.1)
	for i in range(25):
		var piece := BoxMesh.new()
		piece.size = Vector3(1.7, 0.06, 2.3)
		var z := -29.0 + i * 2.4
		var x := 10.5 + sin(float(i) * 0.42) * 2.2
		_add_mesh(generated_root, piece, water, Vector3(x,0.04,z), Vector3.ONE)
	var bank_mat := _mat(Color(0.38,0.32,0.22))
	for i in range(22):
		var rock := _rock_mesh(rng.randf_range(0.25,0.55))
		_add_mesh(generated_root, rock, bank_mat, Vector3(8.4 + sin(float(i)*0.6)*2.2,0.15,-26.0+i*2.5), Vector3.ONE)

func _make_path() -> void:
	var dirt := _mat(Color(0.39, 0.29, 0.20))
	for i in range(22):
		var slab := BoxMesh.new()
		slab.size = Vector3(2.5,0.05,1.4)
		var z := 22.0 - i * 2.15
		var x := -1.0 + sin(float(i)*0.22)*2.1
		_add_mesh(generated_root, slab, dirt, Vector3(x,0.05,z), Vector3.ONE)

func _make_landmark() -> void:
	var stone := _mat(Color(0.33,0.30,0.42))
	var rune := _mat(Color(0.48,0.19,0.83), 0.35, 0.1)
	var base := CylinderMesh.new()
	base.top_radius = 1.5
	base.bottom_radius = 1.8
	base.height = 0.45
	_add_mesh(generated_root, base, stone, Vector3(-8,0.22,-8))
	var crystal := _crystal_mesh(1.2)
	_add_mesh(generated_root, crystal, rune, Vector3(-8,1.65,-8), Vector3(1,1.7,1))
	for i in range(6):
		var shard := _crystal_mesh(rng.randf_range(0.35,0.7))
		var angle := TAU * float(i) / 6.0
		_add_mesh(generated_root, shard, _mat(Color(0.35,0.18,0.62)), Vector3(-8+cos(angle)*2.2,0.5,-8+sin(angle)*2.2), Vector3(1,1.4,1))

func _scatter_forest() -> void:
	var trunk_mat := _mat(Color(0.25,0.16,0.12))
	var leaf_mats := [_mat(Color(0.12,0.26,0.16)), _mat(Color(0.15,0.34,0.20)), _mat(Color(0.19,0.29,0.28))]
	for i in range(115):
		var x := rng.randf_range(-30,30)
		var z := rng.randf_range(-30,30)
		# Leave the player start, central path, stream, and landmark clear.
		if Vector2(x,z).length() < 6.5 or (abs(x) < 3.5 and z > -22 and z < 24):
			continue
		if abs(x - 10.0) < 4.0:
			continue
		var tree := Node3D.new()
		tree.name = "Tree"
		tree.position = Vector3(x,0,z)
		generated_root.add_child(tree)
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.16
		trunk.bottom_radius = 0.25
		trunk.height = rng.randf_range(1.4,2.1)
		_add_mesh(tree,trunk,trunk_mat,Vector3(0,0.8,0))
		var crown := _tree_crown_mesh(rng.randf_range(1.1,1.7))
		var crown_mat: Material = leaf_mats[rng.randi_range(0,leaf_mats.size()-1)]
		_add_mesh(tree,crown,crown_mat,Vector3(0,2.0,0),Vector3(1,rng.randf_range(1.0,1.5),1))
		tree.rotation.y = rng.randf_range(0,TAU)

func _scatter_rocks_and_crystals() -> void:
	var rock_materials := [_mat(Color(0.30,0.31,0.35)),_mat(Color(0.38,0.34,0.32)),_mat(Color(0.24,0.25,0.31))]
	for i in range(78):
		var x := rng.randf_range(-30,30)
		var z := rng.randf_range(-30,30)
		if Vector2(x,z).length() < 5.5 or (abs(x) < 3.0 and z > -22 and z < 24):
			continue
		var size := rng.randf_range(0.3,0.9)
		_add_mesh(generated_root,_rock_mesh(size),rock_materials[rng.randi_range(0,rock_materials.size()-1)],Vector3(x,size*0.35,z),Vector3(1,rng.randf_range(0.6,1.25),1))
	for i in range(14):
		var x := rng.randf_range(-27,27)
		var z := rng.randf_range(-27,27)
		if Vector2(x+8,z+8).length() < 7:
			continue
		_add_mesh(generated_root,_crystal_mesh(rng.randf_range(0.35,0.8)),_mat(Color(0.29,0.20,0.53),0.35,0.1),Vector3(x,0.65,z),Vector3(1,rng.randf_range(1.0,1.8),1))

func _make_ruins() -> void:
	var old_stone := _mat(Color(0.30,0.28,0.34))
	for i in range(7):
		var pillar := BoxMesh.new()
		pillar.size = Vector3(0.7,rng.randf_range(1.2,2.7),0.7)
		var angle := TAU * float(i) / 7.0
		var pos := Vector3(18+cos(angle)*3.0, pillar.size.y*0.5, -13+sin(angle)*3.0)
		_add_mesh(generated_root,pillar,old_stone,pos)
	var lintel := BoxMesh.new()
	lintel.size = Vector3(4.0,0.45,0.65)
	_add_mesh(generated_root,lintel,old_stone,Vector3(18,2.2,-13))

func _rock_mesh(size: float) -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 1.5
	mesh.radial_segments = 6
	mesh.rings = 3
	return mesh

func _crystal_mesh(size: float) -> Mesh:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(size,size*1.8,size)
	mesh.subdivide_width = 0
	return mesh

func _tree_crown_mesh(size: float) -> Mesh:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(size,size*1.8,size)
	mesh.subdivide_width = 0
	return mesh

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	var direction := Vector3(input.x,0,input.y).normalized()
	player.velocity.x = direction.x * move_speed
	player.velocity.z = direction.z * move_speed
	player.velocity.y = 0
	player.move_and_slide()
	if is_instance_valid(camera):
		camera.position = player.position + Vector3(14, 17, 18)
		camera.look_at(player.position, Vector3.UP)
	if player.position.y < -5:
		player.position = Vector3(0,0,8)
