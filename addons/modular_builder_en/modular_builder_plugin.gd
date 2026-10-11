@tool
extends "res://addons/modular_builder_en/modular_builder_editor_vertices.gd"

const ROOF_SUPPORT = preload("res://addons/modular_builder_en/modular_roof_support.gd")

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if active_tool != TOOL_NONE and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		pending_points.clear()
		_editor_sync_elapsed = 1.0
		status_label.text = "Current points cleared."
		update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if _is_detail_tool(active_tool) and event is InputEventMouseMotion:
		_preview_camera = camera
		_preview_screen_position = event.position
		_update_detail_preview()
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	_editor_sync_elapsed = 1.0
	var root := _get_selected_piece()
	if root == null:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if active_tool == TOOL_FOUNDATION:
		var side := _nearest_side_button(camera, event.position)
		if side >= 0:
			_add_foundation_at_side(root, side)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if active_tool == TOOL_NONE:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if active_tool == TOOL_CREATE_VERTEX:
		var create_position := _raycast_piece_mesh(root, camera, event.position)
		if create_position == null:
			status_label.text = "Click a structure surface to create a connection vertex."
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		_create_manual_vertex(root, create_position)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if active_tool == TOOL_MOVE_VERTEX:
		if pending_points.is_empty():
			var selected_vertex := _nearest_vertex(camera, event.position, _get_manual_vertices(root))
			if selected_vertex == null:
				status_label.text = "Click a blue manual vertex to select it."
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			pending_points.append(selected_vertex)
			status_label.text = "Vertex selected. Click the surface where you want to move it."
		else:
			var move_position := _raycast_piece_mesh(root, camera, event.position)
			if move_position == null:
				status_label.text = "Click a structure surface to move the vertex."
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			_move_manual_vertex(root, pending_points[0], move_position)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if active_tool == TOOL_REMOVE_VERTEX:
		var remove_position := _nearest_vertex(camera, event.position, _get_manual_vertices(root))
		if remove_position == null:
			status_label.text = "Click a blue manual vertex to remove it."
		else:
			_remove_manual_vertex(root, remove_position)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if active_tool == TOOL_PILLAR:
		var pillar_vertex := _nearest_vertex(camera, event.position, _get_tool_vertices(root))
		if pillar_vertex == null:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		if event.alt_pressed:
			_create_vertical_pillar_from_vertex(root, pillar_vertex)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		for previous_point in pending_points:
			if previous_point.distance_to(pillar_vertex) < 0.02:
				status_label.text = "Choose a different second vertex."
				return EditorPlugin.AFTER_GUI_INPUT_STOP
		pending_points.append(pillar_vertex)
		if pending_points.size() >= 2:
			_create_pillar_from_vertices(root, pending_points[0], pending_points[1])
		else:
			status_label.text = "First vertex marked. Click another vertex to place the pillar between them."
		update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if active_tool == TOOL_FENCE or active_tool == TOOL_PARAPET:
		var fence_vertex := _nearest_vertex(camera, event.position, _get_tool_vertices(root))
		if fence_vertex == null:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		for previous_point in pending_points:
			if previous_point.distance_to(fence_vertex) < 0.02:
				status_label.text = "Choose a different second vertex for the path."
				return EditorPlugin.AFTER_GUI_INPUT_STOP
		pending_points.append(fence_vertex)
		if pending_points.size() >= 2:
			_create_fence_decoration(root, pending_points[0], pending_points[1])
		else:
			status_label.text = "Start marked. Click the final fence vertex."
		update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if _is_detail_tool(active_tool):
		if _create_detail_from_click(camera, event.position):
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		status_label.text = "Click a surface compatible with the selected tool."
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var point := _nearest_vertex(camera, event.position, _get_tool_vertices(root))
	if point == null:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	for previous_point in pending_points:
		if previous_point.distance_to(point) < 0.02:
			status_label.text = "Choose a different vertex."
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	if active_tool == TOOL_FLOOR_SQUARE and pending_points.size() == 1:
		var first_local := root.to_local(pending_points[0])
		var second_local := root.to_local(point)
		if absf(first_local.x - second_local.x) < 0.02 or absf(first_local.z - second_local.z) < 0.02:
			status_label.text = "To complete a square floor, choose the opposite diagonal vertex."
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	pending_points.append(point)
	var needed := _required_clicks()
	if pending_points.size() >= needed:
		_finish_shape(root)
	elif active_tool == TOOL_ROOF_SHED:
		status_label.text = "Low point marked. Click the high point on the other side of the roof."
	elif active_tool == TOOL_MERGE_VERTICES:
		status_label.text = "First vertex marked. Click the second to merge the markers."
	else:
		status_label.text = "Point %d of %d marked. Click the next vertex." % [pending_points.size(), needed]
	update_overlays()
	return EditorPlugin.AFTER_GUI_INPUT_STOP

func _forward_3d_draw_over_viewport(overlay: Control) -> void:
	pass

func _required_clicks() -> int:
	if active_tool == TOOL_WALL or active_tool == TOOL_GABLE_WALL or active_tool == TOOL_GABLE_WALL_RIGHT or active_tool == TOOL_MERGE_VERTICES or active_tool == TOOL_FLOOR_SQUARE or active_tool == TOOL_ROOF_GABLE or active_tool == TOOL_ROOF_SHED or active_tool == TOOL_ROOF_PYRAMID or active_tool == TOOL_STAIRS or active_tool == TOOL_FENCE:
		return 2
	return 3

func _finish_shape(root: ModularBuilderPiece) -> void:
	if active_tool == TOOL_MERGE_VERTICES:
		_finish_merge_vertices(root)
		return
	if active_tool == TOOL_WALL:
		_finish_wall_segments(root)
		return
	if active_tool == TOOL_GABLE_WALL or active_tool == TOOL_GABLE_WALL_RIGHT:
		_finish_gable_wall(root)
		return
	if active_tool == TOOL_ROOF_GABLE or active_tool == TOOL_ROOF_SHED or active_tool == TOOL_ROOF_PYRAMID:
		_finish_roof(root)
		return
	if active_tool == TOOL_STAIRS:
		_finish_stairs(root)
		return
	if active_tool == TOOL_FENCE:
		_finish_fence(root)
		return
	var local_points := PackedVector3Array()
	for world_point in pending_points:
		local_points.append(root.to_local(world_point))
	var piece := Node3D.new()
	piece.set_script(PIECE_SCRIPT)
	piece.set("centered_origin", true)
	piece.name = "FloorTriangle" if active_tool == TOOL_FLOOR_TRIANGLE else "FloorSquare"
	piece.set("piece_type", ModularBuilderPiece.PieceType.FLOOR)
	piece.set("thickness", root.thickness)
	if active_tool == TOOL_FLOOR_SQUARE:
		var a := local_points[0]
		var b := local_points[1]
		var left := minf(a.x, b.x)
		var right := maxf(a.x, b.x)
		var near_z := minf(a.z, b.z)
		var far_z := maxf(a.z, b.z)
		var y := (a.y + b.y) * 0.5
		local_points = PackedVector3Array([
			Vector3(left, y, near_z), Vector3(right, y, near_z),
			Vector3(right, y, far_z), Vector3(left, y, far_z)
		])
	var floor_pivot := _packed_points_bounds_center(local_points)
	floor_pivot.y -= piece.thickness * 0.5
	piece.position = floor_pivot
	for i in range(local_points.size()):
		local_points[i] -= floor_pivot
	piece.set("custom_points", local_points)
	var undo := get_undo_redo()
	undo.create_action("Create %s from vertices" % piece.name)
	undo.add_do_method(root, "add_child", piece, true)
	undo.add_do_property(piece, "owner", get_editor_interface().get_edited_scene_root())
	undo.add_undo_method(root, "remove_child", piece)
	undo.commit_action()
	_last_created_piece = piece
	pending_points.clear()
	status_label.text = "%s created inside ModularBuilderPiece. The tool remains active." % piece.name
	update_overlays()

func _finish_wall_segments(root: ModularBuilderPiece) -> void:
	var start_world := pending_points[0]
	var finish_world := pending_points[1]
	var path := finish_world - start_world
	var path_length_squared := path.length_squared()
	if path_length_squared < 0.0001:
		pending_points.clear()
		status_label.text = "Wall points are too close together."
		update_overlays()
		return
	var parameters: Array[float] = [0.0, 1.0]
	for vertex in _get_tool_vertices(root):
		var t := (vertex - start_world).dot(path) / path_length_squared
		if t <= 0.001 or t >= 0.999:
			continue
		var projected := start_world + path * t
		if vertex.distance_to(projected) > 0.02:
			continue
		var already_added := false
		for existing_t in parameters:
			if absf(existing_t - t) < 0.005:
				already_added = true
				break
		if not already_added:
			parameters.append(t)
	parameters.sort()
	var pieces: Array[ModularBuilderPiece] = []
	var centralize_wall := _gable_centralize_check.button_pressed
	for i in range(parameters.size() - 1):
		var a_world := start_world.lerp(finish_world, parameters[i])
		var b_world := start_world.lerp(finish_world, parameters[i + 1])
		pieces.append(_make_wall_segment(root, a_world, b_world, i + 1, centralize_wall))
	var scene_root := get_editor_interface().get_edited_scene_root()
	var undo := get_undo_redo()
	undo.create_action("Create wall in %d segments" % pieces.size())
	for piece in pieces:
		undo.add_do_method(root, "add_child", piece, true)
		undo.add_do_property(piece, "owner", scene_root)
		undo.add_undo_method(root, "remove_child", piece)
	undo.commit_action()
	_last_created_piece = pieces[-1]
	pending_points.clear()
	status_label.text = "Wall split into %d segments at foundation vertices." % pieces.size()
	update_overlays()

func _finish_gable_wall(root: ModularBuilderPiece) -> void:
	var start := root.to_local(pending_points[0])
	var finish := root.to_local(pending_points[1])
	if Vector2(start.x - finish.x, start.z - finish.z).length() < 0.02 or absf(start.y - finish.y) > 0.05:
		pending_points.clear()
		status_label.text = "Choose two separate vertices at the same height for the gable base."
		update_overlays()
		return
	var piece_node := Node3D.new()
	piece_node.set_script(PIECE_SCRIPT)
	var piece := piece_node as ModularBuilderPiece
	var is_right_triangle := active_tool == TOOL_GABLE_WALL_RIGHT
	piece.name = "GableWallRight" if is_right_triangle else "GableWall"
	piece.piece_type = ModularBuilderPiece.PieceType.GABLE_WALL_RIGHT if is_right_triangle else ModularBuilderPiece.PieceType.GABLE_WALL
	piece.unit_size = root.unit_size
	piece.thickness = root.thickness
	piece.centered_origin = true
	piece.center_align = _gable_centralize_check.button_pressed
	var pivot := (start + finish) * 0.5 + Vector3.UP * rise_spin.value * 0.5
	piece.position = pivot
	piece.rise = rise_spin.value
	piece.custom_points = PackedVector3Array([start - pivot, finish - pivot])
	var undo := get_undo_redo()
	undo.create_action("Create gable wall")
	undo.add_do_method(root, "add_child", piece, true)
	undo.add_do_property(piece, "owner", get_editor_interface().get_edited_scene_root())
	undo.add_undo_method(root, "remove_child", piece)
	undo.commit_action()
	_last_created_piece = piece
	pending_points.clear()
	status_label.text = "Gable wall created. The tool remains active."
	update_overlays()

func _finish_roof(root: ModularBuilderPiece) -> void:
	var first := root.to_local(pending_points[0])
	var second := root.to_local(pending_points[1])
	var is_gable := active_tool == TOOL_ROOF_GABLE
	var is_pyramid := active_tool == TOOL_ROOF_PYRAMID
	var is_shed := active_tool == TOOL_ROOF_SHED
	if (is_gable or is_pyramid) and absf(first.y - second.y) > 0.05:
		pending_points.clear()
		status_label.text = "For this roof, choose two diagonal points at the same height."
		update_overlays()
		return
	if is_shed and second.y <= first.y + 0.05:
		pending_points.clear()
		status_label.text = "Choose a low point first, then a higher point on the opposite side."
		update_overlays()
		return
	if is_shed and not _shed_points_are_on_opposite_sides(root, pending_points[0], pending_points[1]):
		pending_points.clear()
		status_label.text = "Roof points must be on opposite, parallel walls."
		update_overlays()
		return
	var roof_rise := rise_spin.value
	var roof_width := 0.0
	var corners := PackedVector3Array()
	if is_gable:
		var gable_result := _find_roof_between_gables(root, pending_points[0], pending_points[1])
		if not gable_result.is_empty():
			corners = gable_result.corners
			roof_rise = gable_result.rise
	elif is_pyramid:
		corners = _find_roof_corners(root, first, second)
	else:
		corners = _find_shed_roof_corners(root, first, second)
		if corners.size() == 4:
			roof_width = corners[0].distance_to(corners[1])
	if is_gable and corners.is_empty():
		corners = ROOF_SUPPORT.find_corners(root, pending_points[0], pending_points[1], _simplify_vertices_check.button_pressed)
		if corners.is_empty():
			corners = _find_roof_corners(root, first, second)
	if corners.size() != 4:
		pending_points.clear()
		status_label.text = "Could not find the other roof corners. Choose two diagonal vertices on the top edges of opposite walls."
		update_overlays()
		return
	var piece_node := Node3D.new()
	piece_node.set_script(PIECE_SCRIPT)
	var piece := piece_node as ModularBuilderPiece
	piece.name = "RoofGable" if is_gable else ("RoofPyramid" if is_pyramid else "RoofShed")
	piece.piece_type = ModularBuilderPiece.PieceType.ROOF_GABLE if is_gable else (ModularBuilderPiece.PieceType.ROOF_PYRAMID if is_pyramid else ModularBuilderPiece.PieceType.ROOF_SHED)
	piece.unit_size = root.unit_size
	piece.thickness = 0.05
	piece.centered_origin = true
	piece.rise = roof_rise
	if is_shed:
		piece.roof_width = roof_width
	var pivot := Vector3.ZERO
	for corner in corners:
		pivot += corner
	pivot /= corners.size()
	if is_gable or is_pyramid:
		pivot += Vector3.UP * roof_rise * 0.5
	piece.position = pivot
	if is_gable or is_pyramid:
		var local_corners := PackedVector3Array()
		for corner in corners:
			var local_corner: Vector3 = corner - pivot
			local_corner.y = -roof_rise * 0.5
			local_corners.append(local_corner)
		piece.custom_points = local_corners
	else:
		var local_corners := PackedVector3Array()
		for corner in corners:
			local_corners.append(corner - pivot)
		piece.custom_points = local_corners
	var undo := get_undo_redo()
	var roof_title := "gable roof" if is_gable else ("pyramid roof" if is_pyramid else "shed roof")
	undo.create_action("Create %s" % roof_title)
	undo.add_do_method(root, "add_child", piece, true)
	undo.add_do_property(piece, "owner", get_editor_interface().get_edited_scene_root())
	undo.add_undo_method(root, "remove_child", piece)
	undo.commit_action()
	_last_created_piece = piece
	pending_points.clear()
	status_label.text = "%s created. The tool remains active." % piece.name
	update_overlays()

func _finish_stairs(root: ModularBuilderPiece) -> void:
	if pending_points.size() < 2:
		return
	var low := root.to_local(pending_points[0])
	var high := root.to_local(pending_points[1])
	if high.y <= low.y + 0.05:
		pending_points.clear()
		status_label.text = "Choose the low point first, then a point at least 5 cm higher."
		update_overlays()
		return
	if Vector2(high.x - low.x, high.z - low.z).length() < 0.1:
		pending_points.clear()
		status_label.text = "Stair points need horizontal separation."
		update_overlays()
		return
	var piece_node := Node3D.new()
	piece_node.set_script(PIECE_SCRIPT)
	var piece := piece_node as ModularBuilderPiece
	var pivot := (low + high) * 0.5
	piece.name = "Stairs"
	piece.piece_type = ModularBuilderPiece.PieceType.STAIRS
	piece.position = pivot
	piece.unit_size = root.unit_size
	piece.thickness = 0.1
	piece.centered_origin = true
	piece.stair_count = int(stair_count_spin.value)
	piece.stair_width = stair_width_spin.value
	piece.custom_points = PackedVector3Array([low - pivot, high - pivot])
	var undo := get_undo_redo()
	undo.create_action("Create stairs")
	undo.add_do_method(root, "add_child", piece, true)
	undo.add_do_property(piece, "owner", get_editor_interface().get_edited_scene_root())
	undo.add_undo_method(root, "remove_child", piece)
	undo.commit_action()
	_last_created_piece = piece
	pending_points.clear()
	status_label.text = "Stairs created with %d steps. The tool remains active." % piece.stair_count
	update_overlays()

func _finish_fence(root: ModularBuilderPiece) -> void:
	if pending_points.size() < 2:
		return
	var start := root.to_local(pending_points[0])
	var finish := root.to_local(pending_points[1])
	if start.distance_to(finish) < 0.1:
		pending_points.clear()
		status_label.text = "Choose two points far enough apart for the fence."
		update_overlays()
		return
	var piece_node := Node3D.new()
	piece_node.set_script(PIECE_SCRIPT)
	var piece := piece_node as ModularBuilderPiece
	var pivot := (start + finish) * 0.5
	piece.name = "Fence"
	piece.piece_type = ModularBuilderPiece.PieceType.FENCE
	piece.position = pivot
	piece.unit_size = root.unit_size
	piece.thickness = 0.08
	piece.centered_origin = true
	piece.fence_divisions = int(fence_divisions_spin.value)
	piece.fence_height = 1.0
	piece.custom_points = PackedVector3Array([start - pivot, finish - pivot])
	var undo := get_undo_redo()
	undo.create_action("Create fence")
	undo.add_do_method(root, "add_child", piece, true)
	undo.add_do_property(piece, "owner", get_editor_interface().get_edited_scene_root())
	undo.add_undo_method(root, "remove_child", piece)
	undo.commit_action()
	_last_created_piece = piece
	pending_points.clear()
	status_label.text = "Fence created with %d intermediate post(s). The tool remains active." % piece.fence_divisions
	update_overlays()

func _find_roof_corners(root: ModularBuilderPiece, first: Vector3, second: Vector3) -> PackedVector3Array:
	var diagonal_center := (first + second) * 0.5
	var diagonal_length := first.distance_to(second)
	var candidates: Array[Vector3] = []
	for world_point in _get_tool_vertices(root):
		var local_point := root.to_local(world_point)
		if absf(local_point.y - first.y) > 0.04:
			continue
		_add_unique_vertex(candidates, local_point)
	for adjacent in candidates:
		if adjacent.distance_to(first) < 0.02 or adjacent.distance_to(second) < 0.02:
			continue
		var opposite := diagonal_center * 2.0 - adjacent
		for other_adjacent in candidates:
			if other_adjacent.distance_to(first) < 0.02 or other_adjacent.distance_to(second) < 0.02 or other_adjacent.distance_to(adjacent) < 0.02:
				continue
			if other_adjacent.distance_to(opposite) > 0.04:
				continue
			if absf(adjacent.distance_to(other_adjacent) - diagonal_length) > 0.06:
				continue
			return PackedVector3Array([first, adjacent, second, other_adjacent])
	return PackedVector3Array()

func _find_shed_roof_corners(root: ModularBuilderPiece, low: Vector3, high: Vector3) -> PackedVector3Array:
	var candidates: Array[Vector3] = []
	for world_point in _get_tool_vertices(root):
		_add_unique_vertex(candidates, root.to_local(world_point))
	var match_tolerance := maxf(0.08, root.thickness * 1.5)
	var best := PackedVector3Array()
	var best_score := INF
	for low_adjacent in candidates:
		if absf(low_adjacent.y - low.y) > 0.04 or low_adjacent.distance_to(low) < 0.4:
			continue
		var target_high_adjacent := low + high - low_adjacent
		for high_adjacent in candidates:
			if absf(high_adjacent.y - high.y) > 0.04 or high_adjacent.distance_to(high) < 0.4:
				continue
			var corner_error := high_adjacent.distance_to(target_high_adjacent)
			if corner_error > match_tolerance:
				continue
			var low_edge := Vector2(low_adjacent.x - low.x, low_adjacent.z - low.z)
			var high_edge := Vector2(high.x - high_adjacent.x, high.z - high_adjacent.z)
			if low_edge.length() < 0.4 or high_edge.length() < 0.4:
				continue
			if absf(low_edge.normalized().dot(high_edge.normalized())) < 0.94:
				continue
			var edge_error := absf(low_edge.length() - high_edge.length())
			if edge_error > match_tolerance * 2.0:
				continue
			var score := corner_error + edge_error
			if score < best_score:
				best_score = score
				best = PackedVector3Array([low, low_adjacent, high_adjacent, high])
	return best

func _shed_points_are_on_opposite_sides(root: ModularBuilderPiece, low_world: Vector3, high_world: Vector3) -> bool:
	var low_supports := _get_roof_supports_at_point(root, low_world)
	var high_supports := _get_roof_supports_at_point(root, high_world)
	var across := root.to_local(high_world) - root.to_local(low_world)
	var across_horizontal := Vector2(across.x, across.z)
	if across_horizontal.length() < 0.1:
		return false
	across_horizontal = across_horizontal.normalized()
	for low_support in low_supports:
		for high_support in high_supports:
			if low_support.piece == high_support.piece:
				continue
			var low_direction: Vector2 = low_support.direction
			var high_direction: Vector2 = high_support.direction
			if absf(low_direction.dot(high_direction)) < 0.85:
				continue
			var side_axis := Vector2(-low_direction.y, low_direction.x)
			var center_delta: Vector3 = high_support.center - low_support.center
			var side_separation := absf(Vector2(center_delta.x, center_delta.z).dot(side_axis))
			if side_separation >= 0.4:
				return true
	return false

func _get_roof_supports_at_point(root: ModularBuilderPiece, world_point: Vector3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var walls: Array[Node] = []
	_collect_walls(root, walls)
	for node in walls:
		var wall := node as ModularBuilderPiece
		var endpoints: PackedVector3Array = wall.call("_get_centered_wall_points") if wall.center_align else wall.custom_points
		if endpoints.size() < 2:
			continue
		var world_a := wall.to_global(endpoints[0])
		var world_b := wall.to_global(endpoints[1])
		var local_direction := root.to_local(world_b) - root.to_local(world_a)
		var direction := Vector2(local_direction.x, local_direction.z).normalized()
		var wall_local_direction := (endpoints[1] - endpoints[0]).normalized()
		var side := Vector3(-wall_local_direction.z, 0.0, wall_local_direction.x).normalized() * wall.thickness * 0.5
		for endpoint in endpoints:
			for height in [0.0, wall.unit_size]:
				var center := wall.to_global(endpoint + Vector3.UP * height)
				var support_points := [center + side, center - side]
				if _simplify_vertices_check.button_pressed:
					support_points.append(center)
				for point in support_points:
					if point.distance_to(world_point) <= 0.04:
						result.append({"piece": wall, "direction": direction, "center": root.to_local(center)})
	var gables: Array[Node] = []
	_collect_gable_walls(root, gables)
	for node in gables:
		var gable := node as ModularBuilderPiece
		if gable.custom_points.size() < 2:
			continue
		var base: PackedVector3Array = gable.call("_get_centered_gable_base") if gable.center_align else gable.custom_points
		var a: Vector3 = base[0]
		var b: Vector3 = base[1]
		var local_direction := b - a
		var direction := Vector2(local_direction.x, local_direction.z).normalized()
		var side := Vector3(-local_direction.z, 0.0, local_direction.x).normalized() * gable.thickness * 0.5
		var peak := (a + b) * 0.5 + Vector3.UP * gable.rise if gable.piece_type == ModularBuilderPiece.PieceType.GABLE_WALL else b + Vector3.UP * gable.rise
		var support_points := [a + side, a - side, b + side, b - side, peak + side, peak - side]
		if _simplify_vertices_check.button_pressed:
			support_points.append_array([a, b, peak])
		for point_local in support_points:
			var point := gable.to_global(point_local)
			if point.distance_to(world_point) <= 0.04:
				result.append({"piece": gable, "direction": direction, "center": root.to_local(gable.to_global((a + b) * 0.5))})
	if result.is_empty() and root.has_meta(MERGED_VERTEX_GROUPS_META):
		for group_value in root.get_meta(MERGED_VERTEX_GROUPS_META, []):
			if not group_value is Dictionary:
				continue
			var group: Dictionary = group_value
			var anchor: Vector3 = group.get("position", Vector3.ZERO)
			if root.to_global(anchor).distance_to(world_point) > 0.04:
				continue
			var members: PackedVector3Array = group.get("members", PackedVector3Array())
			for member in members:
				result.append_array(_get_roof_supports_at_point(root, root.to_global(member)))
	return result

func _find_roof_between_gables(root: ModularBuilderPiece, first_world: Vector3, second_world: Vector3) -> Dictionary:
	var gables: Array[Node] = []
	_collect_gable_walls(root, gables)
	var first_gable: ModularBuilderPiece
	var second_gable: ModularBuilderPiece
	var first_base := PackedVector3Array()
	var second_base := PackedVector3Array()
	for node in gables:
		var gable := node as ModularBuilderPiece
		if gable.custom_points.size() < 2:
			continue
		var base: PackedVector3Array = gable.call("_get_centered_gable_base") if gable.center_align else gable.custom_points
		var a: Vector3 = base[0]
		var b: Vector3 = base[1]
		var direction := (b - a).normalized()
		var side := Vector3(-direction.z, 0.0, direction.x).normalized() * gable.thickness * 0.5
		var peak := (a + b) * 0.5 + Vector3.UP * gable.rise if gable.piece_type == ModularBuilderPiece.PieceType.GABLE_WALL else b + Vector3.UP * gable.rise
		var peak_a := gable.to_global(peak + side)
		var peak_b := gable.to_global(peak - side)
		var peak_center := gable.to_global(peak)
		if first_gable == null and (peak_a.distance_to(first_world) < 0.12 or peak_b.distance_to(first_world) < 0.12 or (_simplify_vertices_check.button_pressed and peak_center.distance_to(first_world) < 0.12)):
			first_gable = gable
			first_base = base
		elif second_gable == null and gable != first_gable and (peak_a.distance_to(second_world) < 0.12 or peak_b.distance_to(second_world) < 0.12 or (_simplify_vertices_check.button_pressed and peak_center.distance_to(second_world) < 0.12)):
			second_gable = gable
			second_base = base
	if first_gable == null or second_gable == null:
		return {}
	var a0 := root.to_local(first_gable.to_global(first_base[0]))
	var a1 := root.to_local(first_gable.to_global(first_base[1]))
	var b0 := root.to_local(second_gable.to_global(second_base[0]))
	var b1 := root.to_local(second_gable.to_global(second_base[1]))
	var direct_score := a0.distance_to(b0) + a1.distance_to(b1)
	var crossed_score := a0.distance_to(b1) + a1.distance_to(b0)
	var corners := PackedVector3Array([a0, a1, b1, b0]) if direct_score <= crossed_score else PackedVector3Array([a0, a1, b0, b1])
	return {"corners": corners, "rise": (first_gable.rise + second_gable.rise) * 0.5}

func _make_wall_segment(root: ModularBuilderPiece, start_world: Vector3, finish_world: Vector3, index: int, centralize_wall: bool) -> ModularBuilderPiece:
	var centered_start := _center_wall_anchor(root, start_world) if centralize_wall else start_world
	var centered_finish := _center_wall_anchor(root, finish_world) if centralize_wall else finish_world
	var start := root.to_local(centered_start)
	var finish := root.to_local(centered_finish)
	var piece_node := Node3D.new()
	piece_node.set_script(PIECE_SCRIPT)
	var piece := piece_node as ModularBuilderPiece
	piece.name = "Wall_%02d" % index
	piece.set("piece_type", ModularBuilderPiece.PieceType.WALL)
	piece.set("unit_size", root.unit_size)
	piece.set("thickness", root.thickness)
	piece.set("centered_origin", true)
	piece.set("center_align", centralize_wall)
	var pivot := (start + finish) * 0.5 + Vector3.UP * root.unit_size * 0.5
	piece.position = pivot
	piece.set("custom_points", PackedVector3Array([start - pivot, finish - pivot]))
	return piece

func _center_wall_anchor(root: ModularBuilderPiece, world_point: Vector3) -> Vector3:
	var walls: Array[Node] = []
	_collect_walls(root, walls)
	var best_point := world_point
	var best_distance := INF
	for wall_node in walls:
		var wall := wall_node as ModularBuilderPiece
		var endpoints: PackedVector3Array = wall.call("_get_centered_wall_points") if wall.center_align else wall.custom_points
		if endpoints.size() < 2:
			continue
		var direction := (endpoints[1] - endpoints[0]).normalized()
		var side := Vector3(-direction.z, 0.0, direction.x).normalized() * wall.thickness * 0.5
		for endpoint in endpoints:
			var center := wall.to_global(endpoint + Vector3.UP * wall.unit_size)
			for surface_corner in [center + side, center - side]:
				var distance := world_point.distance_to(surface_corner)
				if distance < best_distance and distance <= wall.thickness + 0.04:
					best_distance = distance
					best_point = center
	return best_point
