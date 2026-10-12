class_name WizardAppearance
extends RefCounted

## The player-created wizard look. Instead of forcing an imported model, players
## pick robe / accent / skin colours, a hat style and whether they carry a staff;
## this builds the figure from low-poly primitives, so it works everywhere and
## can be previewed live in the creator.

var robe := Color(0.24, 0.13, 0.46)
var accent := Color(0.83, 0.75, 0.96)
var skin := Color(0.80, 0.62, 0.52)
var hat := 0          # 0 pointed hat, 1 hood, 2 bare
var staff := true

const ROBES := [
	Color(0.24, 0.13, 0.46), Color(0.52, 0.11, 0.13), Color(0.10, 0.28, 0.50),
	Color(0.10, 0.34, 0.22), Color(0.09, 0.06, 0.15), Color(0.55, 0.40, 0.12),
]
const ACCENTS := [
	Color(0.83, 0.75, 0.96), Color(1.00, 0.72, 0.28), Color(0.36, 0.86, 1.00),
	Color(0.45, 0.95, 0.60), Color(1.00, 0.55, 0.75),
]
const SKINS := [
	Color(0.86, 0.70, 0.58), Color(0.72, 0.50, 0.36), Color(0.45, 0.30, 0.22),
	Color(0.78, 0.82, 0.92), Color(0.62, 0.66, 0.72),
]

func to_dict() -> Dictionary:
	return {"robe": robe, "accent": accent, "skin": skin, "hat": hat, "staff": staff}

func from_dict(d: Dictionary) -> void:
	robe = d.get("robe", robe)
	accent = d.get("accent", accent)
	skin = d.get("skin", skin)
	hat = int(d.get("hat", hat))
	staff = bool(d.get("staff", staff))

func _mat(color: Color, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.72
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.6
	return m

func _part(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat(color, glow)
	parent.add_child(mi)
	return mi

func _sphere(pos: Vector3, radius: float, color: Color, glow: bool = false) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(color, glow)
	return mi

## Build the wizard. The returned node is centred on its own origin with feet at
## y = 0, so it can be dropped under any character body or preview pivot.
func build() -> Node3D:
	var root := Node3D.new()
	root.name = "WizardAppearance"

	var robe_mesh := CylinderMesh.new()
	robe_mesh.top_radius = 0.27
	robe_mesh.bottom_radius = 0.55
	robe_mesh.height = 1.12
	_part(root, robe_mesh, Vector3(0, 0.66, 0), robe)

	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.27
	torso_mesh.height = 0.82
	_part(root, torso_mesh, Vector3(0, 1.12, 0), robe.lightened(0.08))

	var cape_mesh := SphereMesh.new()
	cape_mesh.radius = 0.43
	cape_mesh.height = 1.2
	var cape := _part(root, cape_mesh, Vector3(0, 0.96, 0.18), robe.darkened(0.32))
	cape.scale = Vector3(1.0, 1.0, 0.34)

	for side in [-1.0, 1.0]:
		var sleeve_mesh := CylinderMesh.new()
		sleeve_mesh.top_radius = 0.105
		sleeve_mesh.bottom_radius = 0.14
		sleeve_mesh.height = 0.72
		var sleeve := _part(root, sleeve_mesh, Vector3(side * 0.37, 1.02, -0.005), robe.darkened(0.08))
		sleeve.rotation.z = side * -0.22

		var hand := _sphere(Vector3(side * 0.43, 0.65, -0.035), 0.105, skin)
		hand.scale = Vector3(0.82, 1.0, 0.82)
		root.add_child(hand)

		var boot_mesh := SphereMesh.new()
		boot_mesh.radius = 0.17
		boot_mesh.height = 0.25
		var boot := _part(root, boot_mesh, Vector3(side * 0.19, 0.12, -0.055), Color(0.055, 0.035, 0.075))
		boot.scale = Vector3(1.0, 0.72, 1.25)

	var sash_mesh := TorusMesh.new()
	sash_mesh.inner_radius = 0.265
	sash_mesh.outer_radius = 0.315
	_part(root, sash_mesh, Vector3(0, 0.79, 0), accent)

	var face_mesh := SphereMesh.new()
	face_mesh.radius = 0.235
	face_mesh.height = 0.47
	_part(root, face_mesh, Vector3(0, 1.57, -0.045), skin)

	match hat:
		0:
			var brim_mesh := CylinderMesh.new()
			brim_mesh.top_radius = 0.31
			brim_mesh.bottom_radius = 0.34
			brim_mesh.height = 0.075
			_part(root, brim_mesh, Vector3(0, 1.82, 0), robe.darkened(0.1))
			var hat_mesh := CylinderMesh.new()
			hat_mesh.top_radius = 0.035
			hat_mesh.bottom_radius = 0.245
			hat_mesh.height = 0.52
			var hat_node := _part(root, hat_mesh, Vector3(0, 2.105, 0), robe.darkened(0.12))
			hat_node.rotation.z = -0.08
			var band_mesh := TorusMesh.new()
			band_mesh.inner_radius = 0.222
			band_mesh.outer_radius = 0.245
			_part(root, band_mesh, Vector3(0, 1.91, 0), accent, true)
		1:
			var hood_mesh := SphereMesh.new()
			hood_mesh.radius = 0.29
			hood_mesh.height = 0.42
			var hood := _part(root, hood_mesh, Vector3(0, 1.68, 0.035), robe.darkened(0.2))
			hood.scale = Vector3(1.0, 0.9, 0.9)
			root.add_child(_sphere(Vector3(-0.09, 1.57, -0.238), 0.035, accent, true))
			root.add_child(_sphere(Vector3(0.09, 1.57, -0.238), 0.035, accent, true))
		2:
			var circlet_mesh := TorusMesh.new()
			circlet_mesh.inner_radius = 0.235
			circlet_mesh.outer_radius = 0.255
			_part(root, circlet_mesh, Vector3(0, 1.72, 0), accent, true)

	var pendant := _sphere(Vector3(0, 1.25, -0.285), 0.07, accent, true)
	pendant.scale = Vector3(0.72, 1.0, 0.5)
	root.add_child(pendant)

	if staff:
		var shaft_mesh := CylinderMesh.new()
		shaft_mesh.top_radius = 0.028
		shaft_mesh.bottom_radius = 0.038
		shaft_mesh.height = 1.95
		var shaft := _part(root, shaft_mesh, Vector3(0.62, 0.98, -0.02), Color(0.28, 0.19, 0.12))
		shaft.rotation.z = -0.06
		var orb := _sphere(Vector3(0.68, 2.02, -0.02), 0.105, accent, true)
		root.add_child(orb)

	return root

## A pointed wizard hat, sized to sit on a human head (worn on the rig's head bone).
func build_hat() -> Node3D:
	var hat_node := Node3D.new()
	hat_node.name = "WizardHat"
	var brim_mesh := CylinderMesh.new()
	brim_mesh.top_radius = 0.15
	brim_mesh.bottom_radius = 0.175
	brim_mesh.height = 0.035
	_part(hat_node, brim_mesh, Vector3(0, 0.015, 0), robe.darkened(0.08))
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.015
	cone_mesh.bottom_radius = 0.115
	cone_mesh.height = 0.28
	var cone := _part(hat_node, cone_mesh, Vector3(0, 0.17, 0), robe.darkened(0.14))
	cone.rotation.z = -0.09
	var band_mesh := TorusMesh.new()
	band_mesh.inner_radius = 0.10
	band_mesh.outer_radius = 0.118
	_part(hat_node, band_mesh, Vector3(0, 0.05, 0), accent, true)
	return hat_node

## A hood that covers the head.
func build_hood() -> Node3D:
	var hood := Node3D.new()
	hood.name = "WizardHood"
	var m := SphereMesh.new()
	m.radius = 0.19
	m.height = 0.28
	var h := _part(hood, m, Vector3(0, 0.02, 0.02), robe.darkened(0.2))
	h.scale = Vector3(1.0, 0.95, 0.95)
	return hood

## A staff with a glowing orb, held in the rig's right-hand prop bone.
func build_staff() -> Node3D:
	var staff_node := Node3D.new()
	staff_node.name = "WizardStaff"
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.018
	shaft_mesh.bottom_radius = 0.026
	shaft_mesh.height = 1.5
	_part(staff_node, shaft_mesh, Vector3(0, 0.75, 0), Color(0.28, 0.19, 0.12))
	staff_node.add_child(_sphere(Vector3(0, 1.52, 0), 0.075, accent, true))
	return staff_node