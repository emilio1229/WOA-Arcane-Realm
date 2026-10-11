@tool
extends "res://addons/modular_builder_en/modular_builder_editor_actions.gd"

const PILLAR_SUPPORT = preload("res://addons/modular_builder_en/modular_pillar_support.gd")
const VERTEX_SIMPLIFIER = preload("res://addons/modular_builder_en/modular_vertex_simplifier.gd")

func _create_detail_from_click(camera: Camera3D, screen_position: Vector2) -> bool:
	var placement := _find_detail_placement(camera, screen_position)
	if placement.is_empty():
		return false
	var detail := _new_detail(placement, false)
	var best_piece := placement.host as ModularBuilderPiece
	if best_piece == null:
		return false
	var undo := get_undo_redo()
	undo.create_action("Add %s" % detail.name)
	undo.add_do_method(self, "_attach_detail", best_piece, detail, get_editor_interface().get_edited_scene_root())
	undo.add_undo_method(self, "_detach_detail", best_piece, detail)
	undo.commit_action()
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(detail)
	_set_tool(TOOL_NONE)
	status_label.text = "%s created. Edit style, materials, and dimensions in the Inspector." % detail.name
	return true

func _create_pillar_from_vertices(root: ModularBuilderPiece, first: Vector3, second: Vector3) -> void:
	var placement := _find_pillar_placement(root, first, second)
	if placement.is_empty():
		pending_points.clear()
		status_label.text = "Choose two different structure vertices to connect with the pillar."
		return
	_commit_pillar_placement(placement, "Plain pillar created between vertices. Edit its section and material in the Inspector.")

func _create_vertical_pillar_from_vertex(root: ModularBuilderPiece, anchor: Vector3) -> void:
	pending_points.clear()
	var length := maxf(0.2, detail_height_spin.value * METERS_TO_GODOT_UNITS)
	var direction := _vertical_pillar_direction(root, anchor)
	var placement := _find_pillar_placement(root, anchor, anchor + direction * length)
	if placement.is_empty():
		status_label.text = "Could not place a vertical pillar at this vertex."
		return
	_commit_pillar_placement(placement, "Vertical pillar created from the vertex. Edit its length in the Inspector.")

func _commit_pillar_placement(placement: Dictionary, message: String) -> void:
	var detail := _new_detail(placement, false)
	var host := placement.host as ModularBuilderPiece
	detail.set("height", float(placement.length))
	var undo := get_undo_redo()
	undo.create_action("Add plain pillar")
	undo.add_do_method(self, "_attach_detail", host, detail, get_editor_interface().get_edited_scene_root())
	undo.add_undo_method(self, "_detach_detail", host, detail)
	undo.commit_action()
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(detail)
	_set_tool(TOOL_NONE)
	status_label.text = message

func _vertical_pillar_direction(root: ModularBuilderPiece, anchor: Vector3) -> Vector3:
	var selected_pillar := _get_selected_pillar_detail()
	if selected_pillar != null:
		var pillar_local := selected_pillar.to_local(anchor)
		if absf(pillar_local.x) <= selected_pillar.width * 0.5 + 0.05 and absf(pillar_local.z) <= selected_pillar.width * 0.5 + 0.05 and absf(absf(pillar_local.y) - selected_pillar.height * 0.5) <= 0.05:
			return PILLAR_SUPPORT.vertical_direction_for_pillar(selected_pillar, anchor)
	var source := _get_pillar_vertex_source(root, anchor)
	if source != null:
		return PILLAR_SUPPORT.vertical_direction_for_piece(source, anchor)
	var pillar := _find_pillar_at_vertex(root, anchor)
	return PILLAR_SUPPORT.vertical_direction_for_pillar(pillar, anchor) if pillar != null else Vector3.UP

func _find_pillar_at_vertex(node: Node, anchor: Vector3) -> ModularBuilderDetail:
	if node is ModularBuilderDetail and node.detail_type == ModularBuilderDetail.DetailType.PILLAR:
		var detail := node as ModularBuilderDetail
		var local := detail.to_local(anchor)
		var half := detail.width * 0.5
		var at_corner := absf(absf(local.x) - half) <= 0.05 and absf(absf(local.z) - half) <= 0.05
		var at_center := _simplify_vertices_check != null and _simplify_vertices_check.button_pressed and absf(local.x) <= 0.05 and absf(local.z) <= 0.05
		if (at_corner or at_center) and absf(absf(local.y) - detail.height * 0.5) <= 0.05:
			return detail
	for child in node.get_children():
		var pillar := _find_pillar_at_vertex(child, anchor)
		if pillar != null:
			return pillar
	return null

func _create_fence_decoration(root: ModularBuilderPiece, first: Vector3, second: Vector3) -> void:
	if first.distance_to(second) < 0.05:
		pending_points.clear()
		status_label.text = "Choose two vertices far enough apart."
		return
	var is_parapet := active_tool == TOOL_PARAPET
	var detail := Node3D.new()
	detail.set_script(DETAIL_SCRIPT)
	detail.name = "Parapet" if is_parapet else "Fence"
	detail.set("detail_type", ModularBuilderDetail.DetailType.PARAPET if is_parapet else ModularBuilderDetail.DetailType.FENCE)
	detail.set("detail_mode", ModularBuilderDetail.DetailMode.SEPARATE_OBJECT)
	detail.set("path_points", PackedVector3Array([root.to_local(first), root.to_local(second)]))
	detail.set("fence_height", fence_height_spin.value * METERS_TO_GODOT_UNITS)
	detail.set("fence_divisions", int(fence_divisions_spin.value))
	var undo := get_undo_redo()
	undo.create_action("Add parapet" if is_parapet else "Add decorative fence")
	undo.add_do_method(self, "_attach_detail", root, detail, get_editor_interface().get_edited_scene_root())
	undo.add_undo_method(self, "_detach_detail", root, detail)
	undo.commit_action()
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(detail)
	_set_tool(TOOL_NONE)
	pending_points.clear()
	status_label.text = "%s created with %d intermediate post(s)." % [detail.name, detail.fence_divisions]

func _find_pillar_placement(root: ModularBuilderPiece, first: Vector3, second: Vector3) -> Dictionary:
	if first.distance_to(second) < 0.02:
		return {}
	var local_first := root.to_local(first)
	var local_second := root.to_local(second)
	var segment := local_second - local_first
	var segment_length := segment.length()
	if segment_length < 0.02:
		return {}
	var y_axis := segment / segment_length
	var reference_axis := Vector3.FORWARD if absf(y_axis.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x_axis := reference_axis.cross(y_axis).normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	var basis := Basis(x_axis, y_axis, z_axis).orthonormalized()
	var source := _get_pillar_vertex_source(root, first)
	var alignment_basis := Basis.IDENTITY
	if source != null:
		alignment_basis = (root.global_transform.basis.inverse() * source.global_transform.basis).orthonormalized()
	return {
		"host": root,
		"position": (local_first + local_second) * 0.5,
		"rotation": Vector3.ZERO,
		"basis": basis,
		"direction": segment,
		"alignment_basis": alignment_basis,
		"length": segment_length
	}

func _get_pillar_vertex_source(root: ModularBuilderPiece, point: Vector3) -> ModularBuilderPiece:
	var best_piece: ModularBuilderPiece
	var best_distance := 0.05
	var pieces: Array[ModularBuilderPiece] = []
	call("_collect_all_modular_pieces", root, pieces)
	for piece in pieces:
		if piece.piece_type != ModularBuilderPiece.PieceType.FOUNDATION_SQUARE and piece.piece_type != ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE and piece.piece_type != ModularBuilderPiece.PieceType.FLOOR and piece.piece_type != ModularBuilderPiece.PieceType.WALL and piece.piece_type != ModularBuilderPiece.PieceType.GABLE_WALL and piece.piece_type != ModularBuilderPiece.PieceType.GABLE_WALL_RIGHT:
			continue
		var vertices: Array[Vector3] = []
		call("_collect_piece_geometry_vertices", piece, vertices)
		for vertex in vertices:
			var distance := vertex.distance_to(point)
			if _simplify_vertices_check != null and _simplify_vertices_check.button_pressed:
				distance = minf(distance, VERTEX_SIMPLIFIER.piece_vertex(piece, vertex).distance_to(point))
			if distance < best_distance:
				best_distance = distance
				best_piece = piece
	return best_piece

func _point_inside_surface_or_edge(piece: ModularBuilderPiece, point: Vector2, edge_tolerance: float) -> bool:
	if _point_inside_surface(piece, point):
		return true
	var polygon := _foundation_polygon(piece) if piece.piece_type != ModularBuilderPiece.PieceType.FLOOR else _piece_polygon_xz(piece)
	for i in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		var edge := b - a
		var t := clampf((point - a).dot(edge) / maxf(edge.length_squared(), 0.000001), 0.0, 1.0)
		if point.distance_to(a + edge * t) <= edge_tolerance + 0.01:
			return true
	return false

func _find_detail_placement(camera: Camera3D, screen_position: Vector2) -> Dictionary:
	var root := _get_selected_piece()
	if root == null or not _is_detail_tool(active_tool):
		return {}
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var candidates: Array[ModularBuilderPiece] = []
	if active_tool == TOOL_HATCH or active_tool == TOOL_PILLAR:
		_collect_surface_pieces(root, candidates)
	else:
		_collect_wall_pieces(root, candidates)
	var best_distance := INF
	var best_piece: ModularBuilderPiece
	var best_local := Vector3.ZERO
	var best_surface_y := 0.0
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.piece_type == ModularBuilderPiece.PieceType.BUILDING:
			continue
		var local_origin := candidate.to_local(ray_origin)
		var local_direction := candidate.to_local(ray_origin + ray_direction) - local_origin
		if active_tool != TOOL_HATCH and candidate.custom_points.size() < 2:
			continue
		var uses_surface := active_tool == TOOL_HATCH or active_tool == TOOL_PILLAR
		var plane_normal := Vector3.UP if uses_surface else Vector3(-candidate.custom_points[1].z + candidate.custom_points[0].z, 0.0, candidate.custom_points[1].x - candidate.custom_points[0].x).normalized()
		if uses_surface and candidate.custom_points.size() >= 3:
			plane_normal = Vector3.UP
		if absf(local_direction.dot(plane_normal)) < 0.0001:
			continue
		var plane_y := 0.0
		var plane_point := Vector3.ZERO
		if uses_surface:
			plane_y = candidate.thickness * 0.5 if candidate.centered_origin else candidate.thickness
			plane_point.y = plane_y
		var distance := (plane_point - local_origin).dot(plane_normal) / local_direction.dot(plane_normal)
		if distance < 0.0 or distance >= best_distance:
			continue
		var hit := local_origin + local_direction * distance
		if uses_surface:
			if candidate.piece_type != ModularBuilderPiece.PieceType.FLOOR and candidate.piece_type != ModularBuilderPiece.PieceType.FOUNDATION_SQUARE and candidate.piece_type != ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE:
				continue
			if not _point_inside_surface(candidate, Vector2(hit.x, hit.z)):
				continue
		else:
			if candidate.piece_type != ModularBuilderPiece.PieceType.WALL or candidate.custom_points.size() < 2:
				continue
			var a: Vector3 = candidate.custom_points[0]
			var b: Vector3 = candidate.custom_points[1]
			var wall_dir := (b - a).normalized()
			var along := (hit - a).dot(wall_dir)
			var vertical := hit.y - a.y
			if along < 0.0 or along > a.distance_to(b) or vertical < 0.0 or vertical > candidate.unit_size:
				continue
		best_distance = distance
		best_piece = candidate
		best_local = hit
		best_surface_y = plane_y
	if best_piece == null:
		return {}
	# best_local uses the selected piece’s local coordinates. The child detail
	# must use the same space, especially for attached foundations.
	var host_local := best_local
	var detail_position: Vector3
	var detail_rotation := Vector3.ZERO
	if active_tool == TOOL_HATCH:
		detail_position = Vector3(host_local.x, 0.0, host_local.z)
	elif active_tool == TOOL_PILLAR:
		detail_position = Vector3(host_local.x, best_surface_y, host_local.z)
	else:
		var wall_a: Vector3 = best_piece.custom_points[0]
		var wall_b: Vector3 = best_piece.custom_points[1]
		var direction := (wall_b - wall_a).normalized()
		var n := Vector3(-direction.z, 0.0, direction.x)
		detail_rotation.y = atan2(n.x, n.z)
		var opening_center_y := wall_a.y + detail_height_spin.value * 0.5 + detail_height_offset_spin.value
		detail_position = Vector3((wall_a.x + wall_b.x) * 0.5, opening_center_y, (wall_a.z + wall_b.z) * 0.5)
	return {"host": best_piece, "position": detail_position, "rotation": detail_rotation}

func _new_detail(placement: Dictionary, preview: bool) -> ModularBuilderDetail:
	var detail := Node3D.new()
	detail.set_script(DETAIL_SCRIPT)
	if active_tool == TOOL_WINDOW:
		detail.name = "Window"
	elif active_tool == TOOL_DOOR:
		detail.name = "Door"
	elif active_tool == TOOL_HATCH:
		detail.name = "Hatch"
	elif active_tool == TOOL_PILLAR:
		detail.name = "Pillar"
	elif active_tool == TOOL_FENCE:
		detail.name = "Fence"
	else:
		detail.name = "Parapet"
	if active_tool == TOOL_WINDOW:
		detail.set("detail_type", ModularBuilderDetail.DetailType.WINDOW)
	elif active_tool == TOOL_DOOR:
		detail.set("detail_type", ModularBuilderDetail.DetailType.DOOR)
	elif active_tool == TOOL_HATCH:
		detail.set("detail_type", ModularBuilderDetail.DetailType.HATCH)
	elif active_tool == TOOL_FENCE:
		detail.set("detail_type", ModularBuilderDetail.DetailType.FENCE)
	elif active_tool == TOOL_PARAPET:
		detail.set("detail_type", ModularBuilderDetail.DetailType.PARAPET)
	else:
		detail.set("detail_type", ModularBuilderDetail.DetailType.PILLAR)
	detail.set("width", detail_width_spin.value * METERS_TO_GODOT_UNITS)
	detail.set("height", float(placement.length) if active_tool == TOOL_PILLAR and placement.has("length") else detail_height_spin.value * METERS_TO_GODOT_UNITS)
	detail.set("detail_mode", ModularBuilderDetail.DetailMode.SEPARATE_OBJECT if preview or active_tool == TOOL_PILLAR else detail_mode_option.get_selected_id())
	detail.set("surface_material", _preview_material if preview else null)
	if preview:
		var host := placement.host as ModularBuilderPiece
		var preview_depth := host.thickness if host != null else 0.08
		if active_tool == TOOL_WINDOW or active_tool == TOOL_DOOR:
			preview_depth *= 1.25
		detail.set("follow_host_thickness", false)
		detail.set("frame_depth", preview_depth)
	if active_tool == TOOL_WINDOW:
		detail.set("window_style", _selected_window_style)
	elif active_tool == TOOL_DOOR:
		detail.set("door_style", _selected_door_style)
	if preview:
		detail.name = "ModularBuilderPreview"
		detail.set_meta("modular_builder_preview", true)
	var detail_basis: Basis = placement.basis if placement.has("basis") else Basis.from_euler(placement.rotation)
	detail.transform = Transform3D(detail_basis, placement.position)
	if active_tool == TOOL_PILLAR:
		detail.set("pillar_direction", placement.direction)
		detail.set("pillar_alignment_basis", placement.alignment_basis)
		detail.set("center_align", _pillar_centralize_check.button_pressed)
	if active_tool == TOOL_FENCE or active_tool == TOOL_PARAPET:
		detail.set("fence_height", fence_height_spin.value * METERS_TO_GODOT_UNITS)
		detail.set("fence_divisions", int(fence_divisions_spin.value))
	return detail as ModularBuilderDetail

func _update_detail_preview() -> void:
	if not _is_detail_tool(active_tool) or active_tool == TOOL_FENCE or active_tool == TOOL_PARAPET or _preview_camera == null:
		return
	var placement: Dictionary
	if active_tool == TOOL_PILLAR:
		var root := _get_selected_piece()
		if root == null or pending_points.is_empty():
			if is_instance_valid(_detail_preview):
				_detail_preview.visible = false
			return
		var second_vertex := _nearest_vertex(_preview_camera, _preview_screen_position, call("_get_tool_vertices", root))
		if second_vertex == null:
			if is_instance_valid(_detail_preview):
				_detail_preview.visible = false
			return
		placement = _find_pillar_placement(root, pending_points[0], second_vertex)
	else:
		placement = _find_detail_placement(_preview_camera, _preview_screen_position)
	if placement.is_empty():
		if is_instance_valid(_detail_preview):
			_detail_preview.visible = false
		return
	if not is_instance_valid(_detail_preview) or _detail_preview.detail_type != _detail_type_for_tool(active_tool):
		_clear_detail_preview()
		_detail_preview = _new_detail(placement, true)
		var scene_root := get_editor_interface().get_edited_scene_root()
		if scene_root == null:
			_detail_preview = null
			return
		var preview_host := placement.host as ModularBuilderPiece
		if active_tool == TOOL_PILLAR and preview_host != null:
			preview_host.add_child(_detail_preview, true)
		else:
			scene_root.add_child(_detail_preview, true)
		_detail_preview.owner = scene_root
	_detail_preview.visible = true
	if not is_equal_approx(_detail_preview.width, detail_width_spin.value):
		_detail_preview.width = detail_width_spin.value
	var preview_height := float(placement.length) if active_tool == TOOL_PILLAR and placement.has("length") else detail_height_spin.value
	if not is_equal_approx(_detail_preview.height, preview_height):
		_detail_preview.height = preview_height
	var host := placement.host as ModularBuilderPiece
	if host != null:
		var preview_basis: Basis = placement.basis if placement.has("basis") else Basis.from_euler(placement.rotation)
		if active_tool == TOOL_PILLAR:
			_detail_preview.transform = Transform3D(preview_basis, placement.position)
			_detail_preview.pillar_direction = placement.direction
			_detail_preview.pillar_alignment_basis = placement.alignment_basis
			_detail_preview.center_align = _pillar_centralize_check.button_pressed
		else:
			_detail_preview.global_transform = host.global_transform * Transform3D(preview_basis, placement.position)

func _detail_type_for_tool(tool: String) -> int:
	if tool == TOOL_DOOR:
		return ModularBuilderDetail.DetailType.DOOR
	if tool == TOOL_HATCH:
		return ModularBuilderDetail.DetailType.HATCH
	if tool == TOOL_PILLAR:
		return ModularBuilderDetail.DetailType.PILLAR
	if tool == TOOL_FENCE:
		return ModularBuilderDetail.DetailType.FENCE
	if tool == TOOL_PARAPET:
		return ModularBuilderDetail.DetailType.PARAPET
	return ModularBuilderDetail.DetailType.WINDOW

func _refresh_detail_preview(_value: float = 0.0) -> void:
	if _preview_camera != null:
		_update_detail_preview()

func _clear_detail_preview() -> void:
	if is_instance_valid(_detail_preview):
		_detail_preview.queue_free()
	_detail_preview = null

func _attach_detail(host: ModularBuilderPiece, detail: Node, scene_root: Node) -> void:
	if detail.get_parent() != host:
		host.add_child(detail, true)
	detail.owner = scene_root
	host._rebuild()

func _detach_detail(host: ModularBuilderPiece, detail: Node) -> void:
	if detail.get_parent() == host:
		host.remove_child(detail)
	host._rebuild()

func _collect_surface_pieces(node: Node, pieces: Array[ModularBuilderPiece]) -> void:
	if node is ModularBuilderPiece and (node.piece_type == ModularBuilderPiece.PieceType.FLOOR or node.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_SQUARE or node.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE):
		pieces.append(node)
	for child in node.get_children():
		_collect_surface_pieces(child, pieces)

func _collect_wall_pieces(node: Node, pieces: Array[ModularBuilderPiece]) -> void:
	if node is ModularBuilderPiece and node.piece_type == ModularBuilderPiece.PieceType.WALL:
		pieces.append(node)
	for child in node.get_children():
		_collect_wall_pieces(child, pieces)

func _point_inside_surface(piece: ModularBuilderPiece, point: Vector2) -> bool:
	var polygon := _foundation_polygon(piece) if piece.piece_type != ModularBuilderPiece.PieceType.FLOOR else _piece_polygon_xz(piece)
	if polygon.size() < 3:
		return false
	var inside := false
	var j := polygon.size() - 1
	for i in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[j]
		if (a.y > point.y) != (b.y > point.y) and point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		j = i
	return inside

func _piece_polygon_xz(piece: ModularBuilderPiece) -> Array[Vector2]:
	var polygon: Array[Vector2] = []
	for point in piece.custom_points:
		polygon.append(Vector2(point.x, point.z))
	return polygon

func _nearest_vertex(camera: Camera3D, screen_position: Vector2, vertices: Array[Vector3]) -> Variant:
	var nearest: Variant = null
	var nearest_distance := MARKER_HIT_RADIUS
	for world_point in vertices:
		if camera.is_position_behind(world_point):
			continue
		var distance := camera.unproject_position(world_point).distance_to(screen_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = world_point
	return nearest
