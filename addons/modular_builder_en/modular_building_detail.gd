@tool
class_name ModularBuilderDetail
extends Node3D

enum DetailType { WINDOW, DOOR, HATCH, PILLAR, FENCE, PARAPET }
enum DetailMode { OPENING, SEPARATE_OBJECT }
enum WindowStyle { SINGLE_PANE, CROSS_PANE }
enum DoorStyle { FLAT, PANELED }

@export var detail_type: DetailType = DetailType.WINDOW:
	set(value):
		detail_type = value
		notify_property_list_changed()
		_rebuild()
@export var detail_mode: DetailMode = DetailMode.OPENING:
	set(value):
		detail_mode = value
		notify_property_list_changed()
		_rebuild()
@export var center_align: bool = false:
	set(value):
		center_align = value
		_apply_pillar_alignment()
		notify_property_list_changed()
@export_storage var pillar_direction: Vector3 = Vector3.UP
@export_storage var pillar_alignment_basis: Basis = Basis.IDENTITY
@export var window_style: WindowStyle = WindowStyle.SINGLE_PANE:
	set(value):
		window_style = value
		_rebuild()
@export var door_style: DoorStyle = DoorStyle.FLAT:
	set(value):
		door_style = value
		_rebuild()
@export_range(0.01, 5.0, 0.001, "suffix:m") var width: float = 1.0:
	set(value):
		width = value
		_rebuild()
@export_range(0.2, 5.0, 0.001, "suffix:m") var height: float = 1.0:
	set(value):
		height = value
		_rebuild()
@export_range(0.02, 0.5, 0.001, "suffix:m") var frame_depth: float = 0.08:
	set(value):
		frame_depth = value
		_rebuild()
@export_range(0.1, 8.0, 0.001, "suffix:m") var fence_height: float = 0.7:
	set(value):
		fence_height = value
		_rebuild()
@export_range(0, 100, 1, "suffix: posts") var fence_divisions: int = 1:
	set(value):
		fence_divisions = value
		_rebuild()
@export_storage var path_points: PackedVector3Array = PackedVector3Array()
@export_range(0.01, 0.5, 0.001, "suffix:m") var frame_width: float = 0.08:
	set(value):
		frame_width = value
		_rebuild()
@export var follow_host_thickness: bool = true:
	set(value):
		follow_host_thickness = value
		_rebuild()
@export var surface_material: Material:
	set(value):
		surface_material = value
		_rebuild()
@export var frame_material: Material:
	set(value):
		frame_material = value
		_rebuild()
@export var panel_material: Material:
	set(value):
		panel_material = value
		_rebuild()

func _validate_property(property: Dictionary) -> void:
	var separate_object := detail_mode == DetailMode.SEPARATE_OBJECT
	var is_window := detail_type == DetailType.WINDOW
	var is_door := detail_type == DetailType.DOOR
	var has_frame_and_panel := separate_object and detail_type != DetailType.PILLAR and detail_type != DetailType.FENCE and detail_type != DetailType.PARAPET
	var show_property := true
	match StringName(property.name):
		&"detail_mode":
			show_property = detail_type != DetailType.PILLAR and detail_type != DetailType.FENCE and detail_type != DetailType.PARAPET
		&"center_align":
			show_property = detail_type == DetailType.PILLAR
		&"fence_height", &"fence_divisions":
			show_property = detail_type == DetailType.FENCE or detail_type == DetailType.PARAPET
		&"path_points":
			show_property = false
		&"width":
			show_property = detail_type != DetailType.FENCE and detail_type != DetailType.PARAPET
			if detail_type == DetailType.PILLAR:
				property.hint = PROPERTY_HINT_RANGE
				property.hint_string = "0.01,5.0,0.001,suffix:m"
		&"height":
			show_property = detail_type != DetailType.FENCE and detail_type != DetailType.PARAPET
		&"window_style":
			show_property = is_window and separate_object
		&"door_style":
			show_property = is_door and separate_object
		&"frame_width", &"frame_material", &"panel_material":
			show_property = has_frame_and_panel
		&"follow_host_thickness":
			show_property = has_frame_and_panel
		&"frame_depth":
			show_property = has_frame_and_panel and not follow_host_thickness
		&"surface_material":
			show_property = separate_object
	if not show_property:
		property.usage = PROPERTY_USAGE_NO_EDITOR

func _ready() -> void:
	set_notify_transform(true)
	_rebuild()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree():
		var host := get_parent()
		if host != null and host.has_method("_rebuild"):
			host.call("_rebuild")

func _on_host_thickness_changed() -> void:
	_rebuild(false)

func _apply_pillar_alignment() -> void:
	if detail_type != DetailType.PILLAR:
		return
	var direction := pillar_direction.normalized()
	if direction.is_zero_approx():
		direction = Vector3.UP
	if center_align:
		var object_axes := pillar_alignment_basis.orthonormalized()
		var best_axis := direction
		var best_dot := -1.0
		for axis in [object_axes.x, object_axes.y, object_axes.z]:
			var normalized_axis: Vector3 = axis.normalized()
			var alignment := absf(direction.dot(normalized_axis))
			if alignment > best_dot:
				best_dot = alignment
				best_axis = normalized_axis if direction.dot(normalized_axis) >= 0.0 else -normalized_axis
		direction = best_axis
	var reference_axis := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x_axis := reference_axis.cross(direction).normalized()
	var z_axis := x_axis.cross(direction).normalized()
	transform.basis = Basis(x_axis, direction, z_axis).orthonormalized()
	if center_align and pillar_direction.length() > 0.0:
		height = pillar_direction.length()

func _rebuild(notify_host: bool = true) -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.name == "DetailGeometry":
			remove_child(child)
			child.queue_free()
	var host := get_parent()
	if notify_host and host != null and host.has_method("_rebuild"):
		host.call("_rebuild")
	if detail_mode == DetailMode.OPENING and detail_type != DetailType.FENCE and detail_type != DetailType.PARAPET:
		return
	var holder := Node3D.new()
	holder.name = "DetailGeometry"
	add_child(holder)
	var scene_root: Node = null
	if Engine.is_editor_hint() and not has_meta("modular_builder_preview"):
		scene_root = get_tree().edited_scene_root
	if scene_root:
		holder.owner = scene_root
	var effective_depth := _effective_frame_depth()
	var frame := minf(maxf(frame_width, 0.01), minf(width, height) * 0.45)
	if detail_type == DetailType.FENCE or detail_type == DetailType.PARAPET:
		_build_fence_geometry(holder)
		return
	if detail_type == DetailType.PILLAR:
		_add_box(holder, "PillarBody", Vector3(width, height, width), Vector3.ZERO, surface_material)
		return
	if detail_type == DetailType.HATCH:
		_add_box(holder, "LeftFrame", Vector3(frame, effective_depth, height), Vector3(-width * 0.5 + frame * 0.5, 0.0, 0.0), _frame_material())
		_add_box(holder, "RightFrame", Vector3(frame, effective_depth, height), Vector3(width * 0.5 - frame * 0.5, 0.0, 0.0), _frame_material())
		_add_box(holder, "NearFrame", Vector3(width, effective_depth, frame), Vector3(0.0, 0.0, -height * 0.5 + frame * 0.5), _frame_material())
		_add_box(holder, "FarFrame", Vector3(width, effective_depth, frame), Vector3(0.0, 0.0, height * 0.5 - frame * 0.5), _frame_material())
		_add_box(holder, "HatchPanel", Vector3(width - frame * 2.0, effective_depth * 0.35, height - frame * 2.0), Vector3(0.0, effective_depth * 0.4, 0.0), _panel_material())
		return
	_add_box(holder, "LeftFrame", Vector3(frame, height, effective_depth), Vector3(-width * 0.5 + frame * 0.5, 0.0, 0.0), _frame_material())
	_add_box(holder, "RightFrame", Vector3(frame, height, effective_depth), Vector3(width * 0.5 - frame * 0.5, 0.0, 0.0), _frame_material())
	_add_box(holder, "TopFrame", Vector3(width, frame, effective_depth), Vector3(0.0, height * 0.5 - frame * 0.5, 0.0), _frame_material())
	if detail_type != DetailType.DOOR:
		_add_box(holder, "BottomFrame", Vector3(width, frame, effective_depth), Vector3(0.0, -height * 0.5 + frame * 0.5, 0.0), _frame_material())
	if detail_type == DetailType.WINDOW:
		_add_box(holder, "WindowPanel", Vector3(maxf(width - frame * 2.0, 0.001), maxf(height - frame * 2.0, 0.001), effective_depth * 0.35), Vector3.ZERO, _panel_material())
		if window_style == WindowStyle.CROSS_PANE:
			_add_box(holder, "VerticalMullion", Vector3(frame * 0.55, height - frame * 2.0, effective_depth * 0.4), Vector3.ZERO, _frame_material())
			_add_box(holder, "HorizontalMullion", Vector3(width - frame * 2.0, frame * 0.55, effective_depth * 0.4), Vector3.ZERO, _frame_material())
	elif detail_type == DetailType.DOOR:
		_add_box(holder, "DoorPanel", Vector3(width - frame * 2.0, height - frame, effective_depth * 0.45), Vector3(0.0, -frame * 0.5, 0.0), _panel_material())
		if door_style == DoorStyle.PANELED:
			var inset_depth := maxf(effective_depth * 0.04, 0.005)
			var panel_width := (width - frame * 2.0) * 0.82
			var panel_height := maxf((height - frame) * 0.28, 0.05)
			for panel_index in range(2):
				var panel_y := -frame * 0.5 + (panel_index - 0.5) * (panel_height + frame * 0.25)
				_add_box(holder, "DoorInset_%d" % panel_index, Vector3(panel_width, panel_height, inset_depth), Vector3(0.0, panel_y, effective_depth * 0.24), _frame_material())

func _effective_frame_depth() -> float:
	if follow_host_thickness:
		var host := get_parent()
		if host != null:
			var host_thickness = host.get("thickness")
			if host_thickness is float or host_thickness is int:
				var depth := float(host_thickness)
				if detail_type == DetailType.WINDOW or detail_type == DetailType.DOOR:
					depth *= 1.25
				return maxf(depth, 0.02)
	return frame_depth

func _build_fence_geometry(holder: Node3D) -> void:
	if path_points.size() < 2 or fence_height <= 0.0:
		return
	var start := path_points[0]
	var finish := path_points[1]
	var path := finish - start
	var path_length := path.length()
	if path_length < 0.05:
		return
	var path_axis := path / path_length
	var up_axis := Vector3.UP - path_axis * path_axis.dot(Vector3.UP)
	if up_axis.length_squared() < 0.001:
		up_axis = Vector3.FORWARD - path_axis * path_axis.dot(Vector3.FORWARD)
	up_axis = up_axis.normalized()
	var side_axis := path_axis.cross(up_axis).normalized()
	var post_width := 0.16 if detail_type == DetailType.PARAPET else 0.08
	var post_count := fence_divisions + 2
	var posts: Array[Vector3] = []
	for i in range(post_count):
		var base := start.lerp(finish, float(i) / float(post_count - 1))
		posts.append(base)
		_add_oriented_box(holder, "Post_%d" % i, base + up_axis * fence_height * 0.5, path_axis, up_axis, side_axis, Vector3(post_width, fence_height, post_width))
	for i in range(posts.size() - 1):
		var a := posts[i]
		var b := posts[i + 1]
		var segment := b - a
		var segment_length := segment.length()
		if detail_type == DetailType.PARAPET:
			_add_oriented_box(holder, "Rail_%d" % i, (a + b) * 0.5 + up_axis * fence_height * 0.78, segment.normalized(), up_axis, side_axis, Vector3(segment_length, post_width * 0.8, post_width * 0.8))
		else:
			for height_ratio in [0.28, 0.78]:
				_add_oriented_box(holder, "Rail_%d_%d" % [i, int(height_ratio * 100.0)], (a + b) * 0.5 + up_axis * fence_height * height_ratio, segment.normalized(), up_axis, side_axis, Vector3(segment_length, post_width, post_width))

func _add_oriented_box(holder: Node3D, node_name: String, center: Vector3, axis_x: Vector3, axis_y: Vector3, axis_z: Vector3, dimensions: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = dimensions
	mesh_instance.mesh = box
	var basis := Basis(axis_x.normalized(), axis_y.normalized(), axis_z.normalized()).orthonormalized()
	mesh_instance.transform = Transform3D(basis, center)
	mesh_instance.material_override = surface_material
	holder.add_child(mesh_instance)
	if Engine.is_editor_hint() and not has_meta("modular_builder_preview"):
		var scene_root := get_tree().edited_scene_root
		if scene_root:
			mesh_instance.owner = scene_root

func _frame_material() -> Material:
	return frame_material if frame_material != null else surface_material

func _panel_material() -> Material:
	return panel_material if panel_material != null else surface_material

func _add_box(holder: Node3D, node_name: String, box_size: Vector3, box_position: Vector3, material: Material = null) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.position = box_position
	mesh_instance.material_override = material if material != null else surface_material
	holder.add_child(mesh_instance)
	if Engine.is_editor_hint() and not has_meta("modular_builder_preview"):
		var scene_root := get_tree().edited_scene_root
		if scene_root:
			mesh_instance.owner = scene_root
