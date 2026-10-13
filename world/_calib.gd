extends Node3D

const Materials := preload("res://world/gloamwick_materials.gd")
const OBJ := "res://OBJ/"

var _mesh_cache := {}

func _ready() -> void:
	# Lighting so we can actually see the modules.
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.2, 0.24)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.8)
	e.ambient_light_energy = 1.2
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.4
	add_child(sun)

	# Ground reference plane 6x6.
	_box(Vector3(0, -0.05, 0), Vector3(6, 0.1, 6), Color(0.3, 0.3, 0.32))

	# Four walls of a 6x6 building, 3 modules each (2m modules).
	# North wall (z=-3): exterior should face -Z
	for x in [-2.0, 0.0, 2.0]:
		_place("Wall_Plaster_Straight", Vector3(x, 0, -3.0), 0.0)
	# South wall (z=+3): exterior faces +Z; middle is the door leaf test
	_place("Wall_Plaster_Straight", Vector3(-2.0, 0, 3.0), 0.0)
	_place("Wall_Plaster_Door_Flat", Vector3(0.0, 0, 3.0), 0.0)
	_place("Door_1_Flat", Vector3(0.0, 0, 3.0), 0.0)
	_place("Wall_Plaster_Straight", Vector3(2.0, 0, 3.0), 0.0)
	# isolated door leaf placed alone (to reveal its own offset)
	_place("Door_1_Flat", Vector3(-5.0, 0, 3.0), 0.0)
	# West wall (x=-3)
	for z in [-2.0, 0.0, 2.0]:
		_place("Wall_Plaster_Straight", Vector3(-3.0, 0, z), -PI * 0.5)
	# East wall (x=+3)
	_place("Wall_Plaster_Straight", Vector3(3.0, 0, -2.0), PI * 0.5)
	_place("Wall_Plaster_Window_Wide_Flat", Vector3(3.0, 0, 0.0), PI * 0.5)
	_place("Window_Wide_Flat1", Vector3(3.0, 0, 0.0), PI * 0.5)
	_place("Wall_Plaster_Straight", Vector3(3.0, 0, 2.0), PI * 0.5)
	# window leaves shown flat on the front face at x = -4 and -3
	_place("Window_Wide_Flat1", Vector3(-4.0, 0, 3.2), 0.0)
	_place("Window_Thin_Round1", Vector3(-3.0, 0, 3.2), 0.0)

	# Roof
	_place("Roof_RoundTiles_6x6", Vector3(0, 3.1, 0), 0.0)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 6.5, 16)
	cam.rotation_degrees = Vector3(-16, 0, 0)
	cam.current = true
	add_child(cam)

func _place(mesh_name: String, pos: Vector3, rot_y: float) -> void:
	var path := OBJ + mesh_name + ".obj"
	if not ResourceLoader.exists(path):
		push_warning("missing " + path)
		return
	var r: Resource = load(path)
	var mesh: Mesh
	if r is Mesh:
		mesh = r
	elif r is PackedScene:
		var inst: Node = (r as PackedScene).instantiate()
		for c in inst.get_children():
			if c is MeshInstance3D:
				mesh = c.mesh
				break
		inst.free()
	if mesh == null:
		return
	Materials.apply_to_mesh(mesh)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = rot_y
	add_child(mi)

func _box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	add_child(mi)