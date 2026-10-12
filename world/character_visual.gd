class_name CharacterVisual
extends Node3D

## Wraps an imported character model (the project's Tripo FBX models have no
## rigged animations and are ~1 unit tall), auto-scaling it to a target height
## and giving it procedural life: an idle sway/breathe and an attack lunge.

var _model: Node3D
var _base_y := 0.0
var _height := 1.8
var _phase := 0.0
var _bob := 0.035
var _sway := 0.02
var _busy := false
var _walking := false
var _walk_phase := 0.0

func setup(scene_path: String, target_height: float, yaw_offset: float = PI) -> bool:
	if not ResourceLoader.exists(scene_path):
		push_warning("CharacterVisual: missing model " + scene_path)
		return false
	var loaded := load(scene_path)
	if loaded is PackedScene:
		_model = (loaded as PackedScene).instantiate() as Node3D
	else:
		var mesh := loaded as Mesh
		if mesh == null:
			return false
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		_model = mi
	if _model == null:
		return false
	var aabb := _compute_aabb(_model)
	var raw_height: float = maxf(aabb.size.y, 0.001)
	var s := target_height / raw_height
	_model.scale = Vector3.ONE * s
	# Put the model's feet on the node's origin and centre it in X/Z.
	var centre := aabb.get_center()
	_base_y = -aabb.position.y * s
	_model.position = Vector3(-centre.x * s, _base_y, -centre.z * s)
	_model.rotation.y = yaw_offset
	add_child(_model)
	# These Tripo models are ~1.9 million triangles each; force the lower baked
	# LODs and drop their shadow casting so they stay affordable on modest GPUs.
	_tune_meshes(_model)
	_height = target_height
	_phase = randf() * TAU
	set_process(true)
	return true

func _tune_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.lod_bias = 3.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_tune_meshes(c)

func set_palette_color(_color: Color) -> void:
	pass

## Called when this character throws an attack (visual only).
func attack() -> void:
	if _busy:
		return
	_busy = true
	var tween := create_tween()
	tween.tween_property(self, "position", position + -global_transform.basis.z * 0.35, 0.12)
	tween.parallel().tween_property(self, "rotation:x", -0.18, 0.12)
	tween.tween_property(self, "position", position, 0.22)
	tween.parallel().tween_property(self, "rotation:x", 0.0, 0.22)
	tween.tween_callback(func() -> void: _busy = false)

## Tell the visual whether the character is moving, so it plays a walk cycle.
func set_walking(walking: bool) -> void:
	_walking = walking

func _process(delta: float) -> void:
	if _model == null:
		return
	_phase += delta
	if _walking:
		# A bouncy two-step: the hips bob twice per stride and the body leans
		# forward a touch, so a single unrigged mesh still reads as walking.
		_walk_phase += delta * 9.0
		_model.position.y = _base_y + absf(sin(_walk_phase)) * 0.075
		_model.rotation.z = sin(_walk_phase * 0.5) * 0.045
		_model.rotation.x = 0.07 + sin(_walk_phase) * 0.025
	else:
		_walk_phase = 0.0
		# Idle breathe + subtle sway so a static mesh still reads as "alive".
		_model.position.y = _base_y + sin(_phase * 1.6) * _bob
		_model.rotation.z = sin(_phase * 0.9) * _sway
		_model.rotation.x = sin(_phase * 1.3) * _sway * 0.6

func _compute_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi := n as MeshInstance3D
			var bb: AABB = mi.transform * mi.mesh.get_aabb()
			if first:
				result = bb
				first = false
			else:
				result = result.merge(bb)
		for c in n.get_children():
			stack.append(c)
	return result