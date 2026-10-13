class_name AnimatedCharacter
extends Node3D

## Lightweight procedural placeholder humanoid. Keeps the game playable while
## final character assets are unavailable: idle sway, walk/run cycles, jump bob,
## a simple attack motion, and named head/hand attachment points for wizard gear.
## No imported rig, FBX, textures, or animation resources are required.

var _body: Node3D
var _rig: Node3D
var _head_anchor: Node3D
var _hand_anchor: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _torso: MeshInstance3D
var _active := false
var _tint := Color(0.25, 0.14, 0.42)
var _phase := 0.0
var _blend := Vector2.ZERO
var _moving := false
var _sprinting := false
var _attacking := 0.0

func setup(body: Node3D) -> bool:
	_body = body
	_rig = Node3D.new()
	_rig.name = "PlaceholderHumanoid"
	add_child(_rig)

	var robe_color := _tint
	var robe := _material(robe_color)
	var trim := _material(Color(0.72, 0.53, 0.96))
	var skin := _material(Color(0.72, 0.52, 0.39))
	var dark := _material(Color(0.12, 0.08, 0.19))

	_torso = _mesh_capsule("RobedBody", 0.36, 0.92, robe, Vector3(0, 1.02, 0))
	_rig.add_child(_torso)
	_add_sphere("Shoulders", Vector3(0, 1.42, 0), Vector3(0.48, 0.22, 0.28), trim)
	_add_sphere("Face", Vector3(0, 1.77, 0), Vector3(0.22, 0.25, 0.22), skin)
	_head_anchor = Node3D.new()
	_head_anchor.name = "Head"
	_head_anchor.position = Vector3(0, 1.91, 0)
	_rig.add_child(_head_anchor)

	_left_arm = _make_limb("LeftSleeve", Vector3(-0.43, 1.25, 0), robe)
	_right_arm = _make_limb("RightSleeve", Vector3(0.43, 1.25, 0), robe)
	_left_leg = _make_limb("LeftHem", Vector3(-0.18, 0.42, 0), dark)
	_right_leg = _make_limb("RightHem", Vector3(0.18, 0.42, 0), dark)

	_hand_anchor = Node3D.new()
	_hand_anchor.name = "B-handProp.R"
	_hand_anchor.position = Vector3(0.52, 1.12, 0)
	_rig.add_child(_hand_anchor)

	# A small luminous sigil on the chest makes the temporary models readable.
	var sigil := _mesh_sphere("ChestSigil", Vector3(0, 1.18, -0.285), Vector3(0.09, 0.09, 0.045), _material(Color(0.48, 0.83, 1.0), true))
	_rig.add_child(sigil)
	_active = true
	return true

func _material(color: Color, emission := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.78
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.4
	return mat

func _mesh_capsule(label: String, radius: float, height: float, material: Material, pos: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	return node

func _mesh_sphere(label: String, pos: Vector3, scale_value: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.scale = scale_value * 2.0
	return node

func _add_sphere(label: String, pos: Vector3, scale_value: Vector3, material: Material) -> void:
	_rig.add_child(_mesh_sphere(label, pos, scale_value, material))

func _make_limb(label: String, pos: Vector3, material: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = pos
	var limb := _mesh_capsule("Shape", 0.115, 0.66, material, Vector3(0, -0.22, 0))
	pivot.add_child(limb)
	_rig.add_child(pivot)
	return pivot

func set_tint(color: Color) -> void:
	_tint = color
	if _torso != null and is_instance_valid(_torso):
		_torso.material_override = _material(color)
	for node in [_left_arm, _right_arm]:
		if node != null:
			var shape := node.get_node_or_null("Shape") as MeshInstance3D
			if shape != null:
				shape.material_override = _material(color)

func attach_to_bone(bone_name: String, node: Node3D, offset := Vector3.ZERO) -> bool:
	var anchor: Node3D
	if bone_name == "Head":
		anchor = _head_anchor
	elif bone_name == "B-handProp.R":
		anchor = _hand_anchor
	else:
		return false
	if anchor == null:
		return false
	node.position = offset
	anchor.add_child(node)
	return true

func use_simple_idle() -> void:
	_moving = false
	_sprinting = false

func set_locomotion(input_dir: Vector2, walking: bool, sprinting: bool, delta: float) -> void:
	if not _active:
		return
	_blend = input_dir
	_moving = input_dir.length_squared() > 0.015
	_sprinting = sprinting or not walking

func play_once(clip: StringName, _blend_time: float = 0.15) -> bool:
	if not _active:
		return false
	if String(clip).to_lower().contains("attack") or String(clip).to_lower().contains("cast"):
		_attacking = 0.55
		return true
	return String(clip) == "idle" or String(clip).contains("walk") or String(clip).contains("run")

func attack() -> void:
	_attacking = 0.55

func is_ready() -> bool:
	return _active

func _process(delta: float) -> void:
	if not _active:
		return
	_phase += delta * (9.5 if _moving and _sprinting else (6.5 if _moving else 1.8))
	_attacking = maxf(0.0, _attacking - delta)
	var stride := sin(_phase) * (0.52 if _moving else 0.035)
	if _left_leg != null:
		_left_leg.rotation.x = stride
	if _right_leg != null:
		_right_leg.rotation.x = -stride
	if _left_arm != null:
		_left_arm.rotation.x = -stride * 0.7
	if _right_arm != null:
		_right_arm.rotation.x = stride * 0.7 - (_attacking * 1.8)
	if _rig != null:
		_rig.position.y = absf(sin(_phase * 2.0)) * (0.07 if _moving else 0.015)
		_rig.rotation.z = sin(_phase) * (0.025 if _moving else 0.008)
		if _attacking > 0.0:
			_rig.rotation.y = sin(_attacking * 8.0) * 0.12
		else:
			_rig.rotation.y = 0.0

func is_ready_unused() -> bool:
	return _active
