class_name AnimatedCharacter
extends Node3D

## Drives the rigged humanoid from the "real-controller" addon (56 bones, 24
## locomotion clips) as a drop-in animated visual for any CharacterBody3D.
##
## The addon ships character.tscn as a complete controller with its own script,
## collision and third-person camera. We keep only the rigged mesh + its
## AnimationPlayer / AnimationTree, strip the rest, and feed the existing
## gameplay body's movement into the locomotion state machine so idle, walk,
## run, jump, fall and landing all play for real.

const RIG_SCENE := "res://addons/real-controller/character.tscn"
const PALETTE_TEXTURE := "res://addons/real-controller/HumanAnimations_ColorPalette.png"

var _body: CharacterBody3D
var _anim_tree: AnimationTree
var _anim_player: AnimationPlayer
var _rig: Node3D
var _skeleton: Skeleton3D
var _active := false
var _blend := Vector2.ZERO
var _tint := Color(1, 1, 1, 1)

func setup(body: CharacterBody3D) -> bool:
	if not ResourceLoader.exists(RIG_SCENE):
		push_warning("AnimatedCharacter: rig scene missing")
		return false
	var packed := load(RIG_SCENE) as PackedScene
	if packed == null:
		return false
	var rig := packed.instantiate() as Node3D
	if rig == null:
		return false
	_body = body

	# Strip the addon's own controller: its script, any child scripts (the addon
	# attaches animation.gd which expects its own controller API), its collision
	# (the gameplay body already has one) and its camera (main.gd owns the camera).
	_strip_scripts(rig)
	for extra in ["CameraPivot", "CollisionShape3D"]:
		var node := rig.get_node_or_null(extra)
		if node != null:
			node.queue_free()
	if rig is CollisionObject3D:
		(rig as CollisionObject3D).collision_layer = 0
		(rig as CollisionObject3D).collision_mask = 0

	_anim_tree = rig.get_node_or_null("AnimationTree") as AnimationTree
	_anim_player = rig.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _anim_tree == null or _anim_player == null:
		rig.queue_free()
		return false

	add_child(rig)
	# The addon ships the mesh sunk 0.8 m into the body and tinted flat orange;
	# stand it on the origin and let the texture show through untinted.
	_rig = rig
	_skeleton = _find_skeleton(rig)
	var aabb := _local_aabb(rig, Transform3D.IDENTITY)
	var centre := aabb.get_center()
	rig.position = Vector3(-centre.x, -aabb.position.y, -centre.z)
	_tune_materials(rig)
	# The state machine decides jump/fall/land from an "advance expression" that
	# reads is_on_floor() and velocity. Point it at the real, simulated body.
	if body.is_inside_tree():
		_anim_tree.advance_expression_base_node = _anim_tree.get_path_to(body)
	_anim_tree.active = true
	_anim_player.play(&"idle")
	_active = true
	return true

func _local_aabb(node: Node, acc: Transform3D) -> AABB:
	var result := AABB()
	var first := true
	var xf := acc
	if node is Node3D and node != self:
		xf = acc * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result = xf * (node as MeshInstance3D).mesh.get_aabb()
		first = false
	for child in node.get_children():
		var child_box := _local_aabb(child, xf)
		if child_box.size == Vector3.ZERO and child_box.position == Vector3.ZERO:
			continue
		result = child_box if first else result.merge(child_box)
		first = false
	return result

## The addon attaches an ORANGE material override that hides the mesh's own
## baked colour. Drop the override so the character's real vertex-coloured skin
## and clothing show through.
func _tune_materials(node: Node) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		# The mesh ships a baked body colour we cannot override through its own
		# material, so give the body a fresh override driven by the creator's tone.
		var body_mat := StandardMaterial3D.new()
		body_mat.albedo_color = _tint
		body_mat.roughness = 0.85
		mi.material_override = body_mat
	for child in node.get_children():
		_tune_materials(child)

## Recolour the character (used by the character creator).
func set_tint(color: Color) -> void:
	_tint = color
	if _rig != null:
		_tune_materials(_rig)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

## Parent a prop to a bone (e.g. a staff in the hand). Returns false if the rig
## has no such bone.
func attach_to_bone(bone_name: String, node: Node3D, offset := Vector3.ZERO) -> bool:
	if _skeleton == null or _skeleton.find_bone(bone_name) < 0:
		return false
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone_name
	_skeleton.add_child(attachment)
	node.position = offset
	attachment.add_child(node)
	return true

## Preview helper: freeze the locomotion state machine on a plain idle loop.
func use_simple_idle() -> void:
	if _anim_tree != null:
		_anim_tree.active = false
	if _anim_player != null:
		_anim_player.play(&"idle")

## Feed the player's movement each physics frame.
## input_dir: raw WASD vector (x = right, y = back). walking/sprinting pick the
## clip set; delta smooths the blend so direction changes are not jerky.
func set_locomotion(input_dir: Vector2, walking: bool, sprinting: bool, delta: float) -> void:
	if not _active or _anim_tree == null:
		return
	var target := Vector2(clampf(input_dir.x, -1.0, 1.0), clampf(-input_dir.y, -1.0, 1.0))
	if target.length() > 1.0:
		target = target.normalized()
	_blend = _blend.lerp(target, clampf(delta * 10.0, 0.0, 1.0))
	_anim_tree.set("parameters/Locomotion/WalkBlend/blend_position", _blend)
	_anim_tree.set("parameters/Locomotion/RunBlend/blend_position", _blend)
	_anim_tree.set("parameters/Locomotion/SprintBlend/blend_position", _blend)
	var walk_run_target := 1.0 if not walking else 0.0
	_anim_tree.set("parameters/Locomotion/WalkRunBlend/blend_amount", walk_run_target)
	_anim_tree.set("parameters/Locomotion/SpeedBlend/blend_amount", 1.0 if sprinting else 0.0)

## Play a one-shot animation from the rig's library, if present (used for
## reactions/attacks). Falls back silently when the clip does not exist.
func play_once(clip: StringName, blend: float = 0.15) -> bool:
	if not _active or _anim_player == null:
		return false
	if not _anim_player.has_animation(clip):
		return false
	_anim_player.play(clip, blend)
	return true

func is_ready() -> bool:
	return _active

## Remove every script under the rig, so the addon's own controller code cannot
## run and error against our gameplay node (it expects a different API).
func _strip_scripts(node: Node) -> void:
	for child in node.get_children():
		_strip_scripts(child)
	if node is AnimationPlayer or node is AnimationTree:
		return
	if node.get_script() != null:
		node.set_script(null)