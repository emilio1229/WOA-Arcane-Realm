@tool
extends "res://addons/modular_builder_en/modular_builder_editor_details.gd"

const MESH_PICKER = preload("res://addons/modular_builder_en/modular_mesh_picker.gd")

func _sync_vertex_markers() -> void:
	var root := _get_selected_piece()
	var vertex_points: Array[Vector3] = []
	var side_points: Array[Dictionary] = []
	if root != null:
		if active_tool == TOOL_WALL or active_tool == TOOL_GABLE_WALL or active_tool == TOOL_GABLE_WALL_RIGHT or active_tool == TOOL_FLOOR_SQUARE or active_tool == TOOL_FLOOR_TRIANGLE or active_tool == TOOL_ROOF_GABLE or active_tool == TOOL_ROOF_SHED or active_tool == TOOL_ROOF_PYRAMID or active_tool == TOOL_STAIRS or active_tool == TOOL_FENCE or active_tool == TOOL_PILLAR or active_tool == TOOL_MERGE_VERTICES or active_tool == TOOL_CREATE_VERTEX or active_tool == TOOL_MOVE_VERTEX or active_tool == TOOL_REMOVE_VERTEX:
			vertex_points = _get_tool_vertices(root)
		elif active_tool == TOOL_FOUNDATION:
			side_points = _get_side_button_points(root)
	if root != _marker_root or (root == null and _marker_container != null) or vertex_points.size() != _marker_point_nodes.size() or side_points.size() != _side_button_nodes.size():
		_clear_marker_container()
		_marker_root = root
		if root == null:
			return
		_marker_container = Node3D.new()
		_marker_container.name = "ModularBuilderMarkers"
		root.add_child(_marker_container)
		for _point in vertex_points:
			var marker := Label3D.new()
			marker.text = "●"
			marker.font_size = 56
			marker.pixel_size = 0.004
			marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.no_depth_test = true
			marker.modulate = Color(0.05, 0.58, 1.0)
			marker.outline_size = 8
			marker.outline_modulate = Color.BLACK
			_marker_container.add_child(marker)
			_marker_point_nodes.append(marker)
		for _button in side_points:
			var label := Label3D.new()
			label.text = "+"
			label.font_size = 56
			label.outline_size = 8
			label.outline_modulate = Color.BLACK
			label.pixel_size = 0.01
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.modulate = Color(0.2, 1.0, 0.55)
			_marker_container.add_child(label)
			_side_button_nodes.append(label)
	for i in range(vertex_points.size()):
		_marker_point_nodes[i].position = root.to_local(vertex_points[i])
		var is_pending := false
		for pending_point in pending_points:
			if pending_point.distance_to(vertex_points[i]) < 0.025:
				is_pending = true
				break
		_marker_point_nodes[i].modulate = Color(1.0, 0.88, 0.08) if is_pending else Color(0.05, 0.58, 1.0)
	for i in range(side_points.size()):
		_side_button_nodes[i].position = root.to_local(side_points[i].position)
	if _marker_container:
		_marker_container.visible = active_tool != TOOL_NONE or not side_points.is_empty()

func _clear_marker_container() -> void:
	if is_instance_valid(_marker_container):
		_marker_container.queue_free()
	_marker_container = null
	_marker_root = null
	_marker_point_nodes.clear()
	_side_button_nodes.clear()

func _get_side_button_points(root: ModularBuilderPiece) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for foundation in _get_foundations(root):
		var top_y := foundation.thickness * 0.5 if foundation.centered_origin else foundation.thickness
		var y := top_y + 0.22
		var points := _foundation_polygon(foundation)
		var centroid := Vector2.ZERO
		for point in points:
			centroid += point
		centroid /= points.size()
		for i in range(points.size()):
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i + 1) % points.size()]
			if _foundation_edge_is_occupied(root, foundation, a, b):
				continue
			var midpoint := (a + b) * 0.5
			var outward := (midpoint - centroid).normalized()
			var edge_length := a.distance_to(b)
			var neighbor_polygon: Array[Vector2] = []
			if _foundation_type_selected == ModularBuilderPiece.PieceType.FOUNDATION_SQUARE:
				var square_side := minf(foundation.unit_size, edge_length)
				var edge_direction := (b - a).normalized()
				var square_a := midpoint - edge_direction * square_side * 0.5
				var square_b := midpoint + edge_direction * square_side * 0.5
				neighbor_polygon = [square_a, square_b, square_b + outward * square_side, square_a + outward * square_side]
			elif points.size() == 3:
				for source_point in points:
					neighbor_polygon.append(_reflect_point_across_edge(source_point, a, b))
			else:
				neighbor_polygon = [a, b, a + outward * edge_length]
			var custom_points := PackedVector3Array()
			for neighbor_point in neighbor_polygon:
				var base_y := -foundation.thickness * 0.5 if foundation.centered_origin else 0.0
				var foundation_local := Vector3(neighbor_point.x, base_y, neighbor_point.y)
				custom_points.append(root.to_local(foundation.to_global(foundation_local)))
			result.append({
				"position": foundation.to_global(Vector3(midpoint.x + outward.x * 0.55, y, midpoint.y + outward.y * 0.55)),
				"custom_points": custom_points,
				"foundation": foundation
			})
	return result

func _foundation_edge_is_occupied(root: ModularBuilderPiece, foundation: ModularBuilderPiece, edge_a: Vector2, edge_b: Vector2) -> bool:
	var foundation_base_y := -foundation.thickness * 0.5 if foundation.centered_origin else 0.0
	var edge_a_3d := root.to_local(foundation.to_global(Vector3(edge_a.x, foundation_base_y, edge_a.y)))
	var edge_b_3d := root.to_local(foundation.to_global(Vector3(edge_b.x, foundation_base_y, edge_b.y)))
	var target_a := Vector2(edge_a_3d.x, edge_a_3d.z)
	var target_b := Vector2(edge_b_3d.x, edge_b_3d.z)
	for other in _get_foundations(root):
		if other == foundation:
			continue
		var other_polygon := _foundation_polygon(other)
		for i in range(other_polygon.size()):
			var a := other_polygon[i]
			var b := other_polygon[(i + 1) % other_polygon.size()]
			var other_base_y := -other.thickness * 0.5 if other.centered_origin else 0.0
			var a_in_root := root.to_local(other.to_global(Vector3(a.x, other_base_y, a.y)))
			var b_in_root := root.to_local(other.to_global(Vector3(b.x, other_base_y, b.y)))
			var other_a := Vector2(a_in_root.x, a_in_root.z)
			var other_b := Vector2(b_in_root.x, b_in_root.z)
			if absf(a_in_root.y - edge_a_3d.y) < 0.02 and absf(b_in_root.y - edge_b_3d.y) < 0.02 and _segments_overlap(target_a, target_b, other_a, other_b):
				return true
	return false

func _get_foundations(root: ModularBuilderPiece) -> Array[ModularBuilderPiece]:
	var result: Array[ModularBuilderPiece] = []
	if root.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_SQUARE or root.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE:
		result.append(root)
	for child in root.get_children():
		_collect_foundations(child, result)
	return result

func _collect_foundations(node: Node, result: Array[ModularBuilderPiece]) -> void:
	if node is ModularBuilderPiece and (node.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_SQUARE or node.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE):
		result.append(node)
	for child in node.get_children():
		_collect_foundations(child, result)

func _reflect_point_across_edge(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var edge := b - a
	var projection := a + edge * ((point - a).dot(edge) / edge.length_squared())
	return projection * 2.0 - point

func _nearest_side_button(camera: Camera3D, screen_position: Vector2) -> int:
	var root := _get_selected_piece()
	if root == null:
		return -1
	var buttons := _get_side_button_points(root)
	var closest := MARKER_HIT_RADIUS + 5.0
	var result := -1
	for i in range(buttons.size()):
		var point: Vector3 = buttons[i].position
		if camera.is_position_behind(point):
			continue
		var distance := camera.unproject_position(point).distance_to(screen_position)
		if distance < closest:
			closest = distance
			result = i
	return result

func _add_foundation_at_side(root: ModularBuilderPiece, side: int) -> void:
	var buttons := _get_side_button_points(root)
	if side < 0 or side >= buttons.size():
		return
	var scene_root := get_editor_interface().get_edited_scene_root() as Node3D
	var piece := Node3D.new()
	piece.name = "Foundation"
	piece.set_script(PIECE_SCRIPT)
	var source_foundation: ModularBuilderPiece = buttons[side].foundation
	piece.set("unit_size", source_foundation.unit_size)
	piece.set("thickness", source_foundation.thickness)
	piece.set("centered_origin", true)
	piece.set("piece_type", _foundation_type_selected)
	var points_in_root: PackedVector3Array = buttons[side].custom_points
	var pivot := _packed_points_bounds_center(points_in_root)
	pivot.y += source_foundation.thickness * 0.5
	var custom_points := PackedVector3Array()
	for point in points_in_root:
		custom_points.append(point - pivot)
	piece.position = pivot
	var undo := get_undo_redo()
	undo.create_action("Add foundation to selected side")
	undo.add_do_method(root, "add_child", piece, true)
	undo.add_do_property(piece, "custom_points", custom_points)
	undo.add_do_property(piece, "owner", scene_root)
	undo.add_undo_method(root, "remove_child", piece)
	undo.commit_action()
	_last_created_piece = piece
	status_label.text = "Foundation added to structure."

func _packed_points_bounds_center(points: PackedVector3Array) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return (minimum + maximum) * 0.5

func _get_tool_vertices(root: ModularBuilderPiece) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if active_tool == TOOL_MERGE_VERTICES:
		_collect_all_connection_vertices(root, result)
	elif active_tool == TOOL_CREATE_VERTEX or active_tool == TOOL_MOVE_VERTEX or active_tool == TOOL_REMOVE_VERTEX:
		_collect_all_connection_vertices(root, result)
	elif active_tool == TOOL_STAIRS:
		_collect_stair_vertices(root, result)
	elif active_tool == TOOL_FENCE or active_tool == TOOL_PARAPET:
		_collect_fence_vertices(root, result)
	elif active_tool == TOOL_PILLAR:
		var surfaces: Array[ModularBuilderPiece] = []
		_collect_surface_pieces(root, surfaces)
		for piece in surfaces:
			if piece.piece_type == ModularBuilderPiece.PieceType.BUILDING:
				continue
			var polygon := _piece_polygon_xz(piece) if piece.piece_type == ModularBuilderPiece.PieceType.FLOOR else _foundation_polygon(piece)
			var top_y := piece.custom_points[0].y if piece.piece_type == ModularBuilderPiece.PieceType.FLOOR and not piece.custom_points.is_empty() else (piece.thickness * 0.5 if piece.centered_origin else piece.thickness)
			var bottom_y := top_y - piece.thickness
			for point in polygon:
				_add_unique_vertex(result, piece.to_global(Vector3(point.x, top_y, point.y)))
				_add_unique_vertex(result, piece.to_global(Vector3(point.x, bottom_y, point.y)))
		var walls: Array[Node] = []
		_collect_walls(root, walls)
		for wall_node in walls:
			var wall := wall_node as ModularBuilderPiece
			var endpoints: PackedVector3Array = wall.call("_get_centered_wall_points") if wall.center_align else wall.custom_points
			if endpoints.size() < 2:
				continue
			var direction := (endpoints[1] - endpoints[0]).normalized()
			var side := Vector3(-direction.z, 0.0, direction.x).normalized() * wall.thickness * 0.5
			for endpoint in endpoints:
				for offset in [Vector3.ZERO, Vector3.UP * wall.unit_size]:
					_add_unique_vertex(result, wall.to_global(endpoint + offset + side))
					_add_unique_vertex(result, wall.to_global(endpoint + offset - side))
		_add_gable_wall_vertices(root, result)
	elif active_tool == TOOL_WALL:
		for foundation in _get_foundations(root):
			var top_y := foundation.thickness * 0.5 if foundation.centered_origin else foundation.thickness
			for point in _foundation_polygon(foundation):
				_add_unique_vertex(result, foundation.to_global(Vector3(point.x, top_y, point.y)))
		var surfaces: Array[ModularBuilderPiece] = []
		_collect_surface_pieces(root, surfaces)
		for surface in surfaces:
			if surface.piece_type != ModularBuilderPiece.PieceType.FLOOR:
				continue
			for point in surface.custom_points:
				_add_unique_vertex(result, surface.to_global(point))
		var existing_walls: Array[Node] = []
		_collect_walls(root, existing_walls)
		for wall_node in existing_walls:
			var wall := wall_node as ModularBuilderPiece
			var endpoints: PackedVector3Array = wall.call("_get_centered_wall_points") if wall.center_align else wall.custom_points
			if endpoints.size() < 2:
				continue
			var direction := (endpoints[1] - endpoints[0]).normalized()
			var side := Vector3(-direction.z, 0.0, direction.x) * wall.thickness * 0.5
			for endpoint in endpoints:
				var top := endpoint + Vector3.UP * wall.unit_size
				_add_unique_vertex(result, wall.to_global(top + side))
				_add_unique_vertex(result, wall.to_global(top - side))
		_add_gable_wall_vertices(root, result)
	else:
		var walls: Array[Node] = []
		_collect_walls(root, walls)
		for wall_node in walls:
			var wall := wall_node as ModularBuilderPiece
			var endpoints: PackedVector3Array = wall.call("_get_centered_wall_points") if wall.center_align else wall.custom_points
			if endpoints.size() < 2:
				continue
			var direction := (endpoints[1] - endpoints[0]).normalized()
			var side := Vector3(-direction.z, 0.0, direction.x).normalized() * float(wall.get("thickness")) * 0.5
			for endpoint in endpoints:
				if active_tool == TOOL_ROOF_GABLE or active_tool == TOOL_ROOF_SHED:
					_add_unique_vertex(result, wall.to_global(endpoint + side))
					_add_unique_vertex(result, wall.to_global(endpoint - side))
				var top := endpoint + Vector3.UP * float(wall.get("unit_size"))
				_add_unique_vertex(result, wall.to_global(top + side))
				_add_unique_vertex(result, wall.to_global(top - side))
		_add_gable_wall_vertices(root, result)
	_collect_detail_connection_vertices(root, result)
	for manual_vertex in _get_manual_vertices(root):
		_add_unique_vertex(result, manual_vertex)
	_collapse_merged_vertex_groups(root, result)
	if _marker_scope_check != null and _marker_scope_check.button_pressed:
		var scope_pieces := _get_marker_scope_pieces(root)
		var scope_vertices: Array[Vector3] = []
		for piece in scope_pieces:
			_collect_piece_geometry_vertices(piece, scope_vertices)
			for manual_vertex in _get_manual_vertices(piece):
				_add_unique_vertex(scope_vertices, manual_vertex)
		for selected_node in get_editor_interface().get_selection().get_selected_nodes():
			if selected_node is ModularBuilderDetail:
				_collect_detail_connection_vertices(selected_node, scope_vertices)
		_collapse_merged_vertex_groups(root, scope_vertices)
		var filtered: Array[Vector3] = []
		for vertex in result:
			for scope_vertex in scope_vertices:
				if vertex.distance_to(scope_vertex) < 0.025:
						_add_unique_vertex(filtered, vertex)
						break
		result = filtered
	if _simplify_vertices_check != null and _simplify_vertices_check.button_pressed and active_tool != TOOL_MERGE_VERTICES and active_tool != TOOL_CREATE_VERTEX and active_tool != TOOL_MOVE_VERTEX and active_tool != TOOL_REMOVE_VERTEX:
		result = _simplify_tool_vertices(root, result)
	return result

func _simplify_tool_vertices(root: ModularBuilderPiece, vertices: Array[Vector3]) -> Array[Vector3]:
	var replacements := {}
	var pieces: Array[ModularBuilderPiece] = []
	_collect_all_modular_pieces(root, pieces)
	for piece in pieces:
		if piece.piece_type != ModularBuilderPiece.PieceType.FOUNDATION_SQUARE and piece.piece_type != ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE and piece.piece_type != ModularBuilderPiece.PieceType.FLOOR and piece.piece_type != ModularBuilderPiece.PieceType.WALL and piece.piece_type != ModularBuilderPiece.PieceType.GABLE_WALL and piece.piece_type != ModularBuilderPiece.PieceType.GABLE_WALL_RIGHT:
			continue
		var piece_vertices: Array[Vector3] = []
		_collect_piece_geometry_vertices(piece, piece_vertices)
		for original in piece_vertices:
			var key := _vertex_position_key(original)
			if not replacements.has(key):
				replacements[key] = VERTEX_SIMPLIFIER.piece_vertex(piece, original)
	_add_pillar_simplification_candidates(root, replacements)
	var result: Array[Vector3] = []
	for original in vertices:
		_add_unique_vertex(result, replacements.get(_vertex_position_key(original), original))
	return result

func _add_pillar_simplification_candidates(node: Node, replacements: Dictionary) -> void:
	if node is ModularBuilderDetail:
		var detail := node as ModularBuilderDetail
		if detail.detail_type == ModularBuilderDetail.DetailType.PILLAR:
			var half := detail.width * 0.5
			for x in [-half, half]:
				for y in [-detail.height * 0.5, detail.height * 0.5]:
					for z in [-half, half]:
						var original := detail.to_global(Vector3(x, y, z))
						var key := _vertex_position_key(original)
						if not replacements.has(key):
							replacements[key] = VERTEX_SIMPLIFIER.pillar_vertex(detail, original)
	for child in node.get_children():
		_add_pillar_simplification_candidates(child, replacements)

func _vertex_position_key(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x * 1000.0), roundi(point.y * 1000.0), roundi(point.z * 1000.0))

func _collect_stair_vertices(root: ModularBuilderPiece, vertices: Array[Vector3]) -> void:
	var surfaces: Array[ModularBuilderPiece] = []
	_collect_surface_pieces(root, surfaces)
	for surface in surfaces:
		var polygon := _piece_polygon_xz(surface) if surface.piece_type == ModularBuilderPiece.PieceType.FLOOR else _foundation_polygon(surface)
		var y := surface.thickness * 0.5 if surface.centered_origin else surface.thickness
		for point in polygon:
			_add_unique_vertex(vertices, surface.to_global(Vector3(point.x, y, point.y)))
	var walls: Array[Node] = []
	_collect_walls(root, walls)
	for wall_node in walls:
		var wall := wall_node as ModularBuilderPiece
		var endpoints: PackedVector3Array = wall.call("_get_centered_wall_points") if wall.center_align else wall.custom_points
		if endpoints.size() < 2:
			continue
		var direction := (endpoints[1] - endpoints[0]).normalized()
		var side := Vector3(-direction.z, 0.0, direction.x) * wall.thickness * 0.5
		for endpoint in endpoints:
			var top := endpoint + Vector3.UP * wall.unit_size
			_add_unique_vertex(vertices, wall.to_global(top + side))
			_add_unique_vertex(vertices, wall.to_global(top - side))
	_add_gable_wall_vertices(root, vertices)

func _collect_fence_vertices(root: ModularBuilderPiece, vertices: Array[Vector3]) -> void:
	var surfaces: Array[ModularBuilderPiece] = []
	_collect_surface_pieces(root, surfaces)
	for surface in surfaces:
		var polygon := _piece_polygon_xz(surface) if surface.piece_type == ModularBuilderPiece.PieceType.FLOOR else _foundation_polygon(surface)
		var top_y := surface.thickness * 0.5 if surface.centered_origin else surface.thickness
		for point in polygon:
			_add_unique_vertex(vertices, surface.to_global(Vector3(point.x, top_y, point.y)))
	var walls: Array[Node] = []
	_collect_walls(root, walls)
	for wall_node in walls:
		var wall := wall_node as ModularBuilderPiece
		var endpoints: PackedVector3Array = wall.call("_get_centered_wall_points") if wall.center_align else wall.custom_points
		if endpoints.size() < 2:
			continue
		var direction := (endpoints[1] - endpoints[0]).normalized()
		var side := Vector3(-direction.z, 0.0, direction.x) * wall.thickness * 0.5
		for endpoint in endpoints:
			for height in [0.0, wall.unit_size]:
				_add_unique_vertex(vertices, wall.to_global(endpoint + Vector3.UP * height + side))
				_add_unique_vertex(vertices, wall.to_global(endpoint + Vector3.UP * height - side))
	_add_gable_wall_vertices(root, vertices)

func _get_marker_scope_pieces(root: ModularBuilderPiece) -> Array[ModularBuilderPiece]:
	var result: Array[ModularBuilderPiece] = []
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	for selected_node in selected:
		var piece := selected_node as ModularBuilderPiece
		if piece == null and selected_node is ModularBuilderDetail:
			var parent := selected_node.get_parent()
			while parent != null and not parent is ModularBuilderPiece:
				parent = parent.get_parent()
			piece = parent as ModularBuilderPiece
		if piece == root:
			_collect_all_modular_pieces(root, result)
			return result
		if piece != null and _is_descendant_of_piece(piece, root):
			if not result.has(piece):
				result.append(piece)
	return result

func _collect_all_modular_pieces(node: Node, result: Array[ModularBuilderPiece]) -> void:
	if node is ModularBuilderPiece and not result.has(node):
		result.append(node)
	for child in node.get_children():
		_collect_all_modular_pieces(child, result)

func _is_descendant_of_piece(node: Node, ancestor: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false

func _collect_piece_geometry_vertices(piece: ModularBuilderPiece, vertices: Array[Vector3]) -> void:
	if piece.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_SQUARE or piece.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE:
		var top_y := piece.thickness * 0.5 if piece.centered_origin else piece.thickness
		var bottom_y := -piece.thickness * 0.5 if piece.centered_origin else 0.0
		for point in _foundation_polygon(piece):
			_add_unique_vertex(vertices, piece.to_global(Vector3(point.x, top_y, point.y)))
			_add_unique_vertex(vertices, piece.to_global(Vector3(point.x, bottom_y, point.y)))
	elif piece.piece_type == ModularBuilderPiece.PieceType.FLOOR:
		for point in piece.custom_points:
			_add_unique_vertex(vertices, piece.to_global(point))
			_add_unique_vertex(vertices, piece.to_global(point - Vector3.UP * piece.thickness))
	elif piece.piece_type == ModularBuilderPiece.PieceType.WALL:
		var endpoints: PackedVector3Array = piece.call("_get_centered_wall_points") if piece.center_align else piece.custom_points
		if endpoints.size() < 2:
			return
		var direction := (endpoints[1] - endpoints[0]).normalized()
		var side := Vector3(-direction.z, 0.0, direction.x) * piece.thickness * 0.5
		for endpoint in endpoints:
			for height in [0.0, piece.unit_size]:
				_add_unique_vertex(vertices, piece.to_global(endpoint + Vector3.UP * height + side))
				_add_unique_vertex(vertices, piece.to_global(endpoint + Vector3.UP * height - side))
	elif piece.piece_type == ModularBuilderPiece.PieceType.GABLE_WALL or piece.piece_type == ModularBuilderPiece.PieceType.GABLE_WALL_RIGHT:
		_add_single_gable_wall_vertices(piece, vertices)
	elif piece.piece_type == ModularBuilderPiece.PieceType.ROOF_GABLE or piece.piece_type == ModularBuilderPiece.PieceType.ROOF_SHED or piece.piece_type == ModularBuilderPiece.PieceType.ROOF_PYRAMID:
		for point in piece.custom_points:
			_add_unique_vertex(vertices, piece.to_global(point))
		if piece.piece_type == ModularBuilderPiece.PieceType.ROOF_PYRAMID and piece.custom_points.size() >= 4:
			var base_center := (piece.custom_points[0] + piece.custom_points[1] + piece.custom_points[2] + piece.custom_points[3]) * 0.25
			_add_unique_vertex(vertices, piece.to_global(base_center + Vector3.UP * piece.rise))

func _collect_all_connection_vertices(root: ModularBuilderPiece, vertices: Array[Vector3]) -> void:
	var surfaces: Array[ModularBuilderPiece] = []
	_collect_surface_pieces(root, surfaces)
	for piece in surfaces:
		var polygon := _piece_polygon_xz(piece) if piece.piece_type == ModularBuilderPiece.PieceType.FLOOR else _foundation_polygon(piece)
		var top_y := piece.thickness * 0.5 if piece.centered_origin else piece.thickness
		var bottom_y := -piece.thickness * 0.5 if piece.centered_origin else 0.0
		for point in polygon:
			_add_unique_vertex(vertices, piece.to_global(Vector3(point.x, top_y, point.y)))
			_add_unique_vertex(vertices, piece.to_global(Vector3(point.x, bottom_y, point.y)))
	var walls: Array[Node] = []
	_collect_walls(root, walls)
	for wall_node in walls:
		var wall := wall_node as ModularBuilderPiece
		var endpoints: PackedVector3Array = wall.call("_get_centered_wall_points") if wall.center_align else wall.custom_points
		if endpoints.size() < 2:
			continue
		var direction := (endpoints[1] - endpoints[0]).normalized()
		var side := Vector3(-direction.z, 0.0, direction.x) * wall.thickness * 0.5
		for endpoint in endpoints:
			for height in [0.0, wall.unit_size]:
				_add_unique_vertex(vertices, wall.to_global(endpoint + Vector3.UP * height + side))
				_add_unique_vertex(vertices, wall.to_global(endpoint + Vector3.UP * height - side))
	_add_gable_wall_vertices(root, vertices)
	_collect_detail_connection_vertices(root, vertices)
	var roofs: Array[ModularBuilderPiece] = []
	_collect_roof_pieces(root, roofs)
	for roof in roofs:
		for point in roof.custom_points:
			_add_unique_vertex(vertices, roof.to_global(point))
		if roof.piece_type == ModularBuilderPiece.PieceType.ROOF_PYRAMID and roof.custom_points.size() >= 4:
			var base_center := (roof.custom_points[0] + roof.custom_points[1] + roof.custom_points[2] + roof.custom_points[3]) * 0.25
			_add_unique_vertex(vertices, roof.to_global(base_center + Vector3.UP * roof.rise))

func _collect_roof_pieces(node: Node, roofs: Array[ModularBuilderPiece]) -> void:
	if node is ModularBuilderPiece and (node.piece_type == ModularBuilderPiece.PieceType.ROOF_GABLE or node.piece_type == ModularBuilderPiece.PieceType.ROOF_SHED or node.piece_type == ModularBuilderPiece.PieceType.ROOF_PYRAMID):
		roofs.append(node)
	for child in node.get_children():
		_collect_roof_pieces(child, roofs)

func _collect_detail_connection_vertices(node: Node, vertices: Array[Vector3]) -> void:
	if node is ModularBuilderDetail:
		var detail := node as ModularBuilderDetail
		if detail.detail_type == ModularBuilderDetail.DetailType.PILLAR:
			var half := detail.width * 0.5
			for x in [-half, half]:
				for y in [-detail.height * 0.5, detail.height * 0.5]:
					for z in [-half, half]:
						_add_unique_vertex(vertices, detail.to_global(Vector3(x, y, z)))
		elif (detail.detail_type == ModularBuilderDetail.DetailType.FENCE or detail.detail_type == ModularBuilderDetail.DetailType.PARAPET) and detail.path_points.size() >= 2:
			for point in detail.path_points:
				_add_unique_vertex(vertices, detail.to_global(point))
		for local_point in detail.get_meta(CUSTOM_VERTICES_META, []):
			_add_unique_vertex(vertices, detail.to_global(local_point))
	for child in node.get_children():
		_collect_detail_connection_vertices(child, vertices)

func _collapse_merged_vertex_groups(root: ModularBuilderPiece, vertices: Array[Vector3]) -> void:
	if not root.has_meta(MERGED_VERTEX_GROUPS_META):
		return
	var groups: Array = root.get_meta(MERGED_VERTEX_GROUPS_META, [])
	for group_value in groups:
		if not group_value is Dictionary:
			continue
		var group: Dictionary = group_value
		var members: PackedVector3Array = group.get("members", PackedVector3Array())
		var anchor: Vector3 = group.get("position", Vector3.ZERO)
		var had_member := false
		for i in range(vertices.size() - 1, -1, -1):
			var local_vertex := root.to_local(vertices[i])
			for member in members:
				if local_vertex.distance_to(member) <= 0.025:
					vertices.remove_at(i)
					had_member = true
					break
		if had_member:
			_add_unique_vertex(vertices, root.to_global(anchor))

func _merge_members_for_point(root: ModularBuilderPiece, world_point: Vector3) -> PackedVector3Array:
	var local_point := root.to_local(world_point)
	var groups: Array = root.get_meta(MERGED_VERTEX_GROUPS_META, [])
	for group_value in groups:
		if not group_value is Dictionary:
			continue
		var group: Dictionary = group_value
		var anchor: Vector3 = group.get("position", Vector3.ZERO)
		if local_point.distance_to(anchor) <= 0.04:
			return group.get("members", PackedVector3Array())
	return PackedVector3Array([local_point])

func _finish_merge_vertices(root: ModularBuilderPiece) -> void:
	if pending_points.size() < 2:
		return
	var selected_members := _merge_members_for_point(root, pending_points[0])
	for member in _merge_members_for_point(root, pending_points[1]):
		var found := false
		for existing in selected_members:
			if existing.distance_to(member) <= 0.025:
				found = true
				break
		if not found:
			selected_members.append(member)
	if selected_members.size() < 2:
		pending_points.clear()
		status_label.text = "Choose two different vertices to merge."
		update_overlays()
		return
	var old_groups: Array = root.get_meta(MERGED_VERTEX_GROUPS_META, []).duplicate(true)
	var new_groups: Array = []
	for group_value in old_groups:
		if not group_value is Dictionary:
			continue
		var group: Dictionary = group_value
		var members: PackedVector3Array = group.get("members", PackedVector3Array())
		var overlaps := false
		for member in members:
			for selected in selected_members:
				if member.distance_to(selected) <= 0.025:
					overlaps = true
					break
			if overlaps:
				break
		if not overlaps:
			new_groups.append(group)
	var center := Vector3.ZERO
	for member in selected_members:
		center += member
	center /= selected_members.size()
	new_groups.append({"members": selected_members, "position": center})
	var undo := get_undo_redo()
	undo.create_action("Merge vertex markers")
	undo.add_do_method(root, "set_meta", MERGED_VERTEX_GROUPS_META, new_groups)
	undo.add_undo_method(root, "set_meta", MERGED_VERTEX_GROUPS_META, old_groups)
	undo.commit_action()
	pending_points.clear()
	status_label.text = "Markers merged. Ctrl+Z undoes the merge."
	update_overlays()

func _add_gable_wall_vertices(root: ModularBuilderPiece, vertices: Array[Vector3]) -> void:
	var gable_walls: Array[Node] = []
	_collect_gable_walls(root, gable_walls)
	for node in gable_walls:
		_add_single_gable_wall_vertices(node as ModularBuilderPiece, vertices)

func _add_single_gable_wall_vertices(gable: ModularBuilderPiece, vertices: Array[Vector3]) -> void:
	if gable.custom_points.size() < 2:
		return
	var base_points: PackedVector3Array = gable.call("_get_centered_gable_base") if gable.center_align else gable.custom_points
	var a: Vector3 = base_points[0]
	var b: Vector3 = base_points[1]
	var direction := (b - a).normalized()
	var side := Vector3(-direction.z, 0.0, direction.x).normalized() * gable.thickness * 0.5
	var peak := (a + b) * 0.5 + Vector3.UP * gable.rise if gable.piece_type == ModularBuilderPiece.PieceType.GABLE_WALL else b + Vector3.UP * gable.rise
	for endpoint in [a, b]:
		_add_unique_vertex(vertices, gable.to_global(endpoint + side))
		_add_unique_vertex(vertices, gable.to_global(endpoint - side))
	_add_unique_vertex(vertices, gable.to_global(peak + side))
	_add_unique_vertex(vertices, gable.to_global(peak - side))

func _collect_gable_walls(node: Node, gable_walls: Array[Node]) -> void:
	if node is ModularBuilderPiece and (node.piece_type == ModularBuilderPiece.PieceType.GABLE_WALL or node.piece_type == ModularBuilderPiece.PieceType.GABLE_WALL_RIGHT) and not gable_walls.has(node):
		gable_walls.append(node)
	for child in node.get_children():
		_collect_gable_walls(child, gable_walls)

func _collect_walls(node: Node, walls: Array[Node]) -> void:
	if node is ModularBuilderPiece and node.piece_type == ModularBuilderPiece.PieceType.WALL and not walls.has(node):
		walls.append(node)
	for child in node.get_children():
		if child is ModularBuilderPiece and child.piece_type == ModularBuilderPiece.PieceType.WALL:
			if not walls.has(child):
				walls.append(child)
		_collect_walls(child, walls)

func _add_unique_vertex(vertices: Array[Vector3], point: Vector3) -> void:
	for existing in vertices:
		if existing.distance_to(point) < 0.02:
			return
	vertices.append(point)

func _get_manual_vertices(piece: ModularBuilderPiece) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var owners: Array[Node3D] = []
	_collect_manual_vertex_owners(piece, owners)
	for owner_node in owners:
		for local_point_value in owner_node.get_meta(CUSTOM_VERTICES_META, []):
			var local_point: Vector3 = local_point_value
			result.append(owner_node.to_global(local_point))
	return result

func _collect_manual_vertex_owners(node: Node, owners: Array[Node3D]) -> void:
	if node is ModularBuilderPiece or node is ModularBuilderDetail:
		owners.append(node as Node3D)
	for child in node.get_children():
		_collect_manual_vertex_owners(child, owners)

func _raycast_piece_mesh(root: ModularBuilderPiece, camera: Camera3D, screen_position: Vector2) -> Variant:
	return MESH_PICKER.raycast(root, camera, screen_position)

func _commit_manual_vertices(owner_node: Node3D, new_vertices: Array, action_name: String) -> void:
	var old_vertices: Array = owner_node.get_meta(CUSTOM_VERTICES_META, []).duplicate()
	var undo := get_undo_redo()
	undo.create_action(action_name)
	undo.add_do_method(owner_node, "set_meta", CUSTOM_VERTICES_META, new_vertices)
	undo.add_undo_method(owner_node, "set_meta", CUSTOM_VERTICES_META, old_vertices)
	undo.commit_action()

func _create_manual_vertex(root: ModularBuilderPiece, world_position: Vector3) -> void:
	var owner_node := _get_vertex_attachment_node(root)
	var local_position := owner_node.to_local(world_position)
	var vertices: Array = owner_node.get_meta(CUSTOM_VERTICES_META, []).duplicate()
	for existing in vertices:
		var existing_position: Vector3 = existing
		if existing_position.distance_to(local_position) < 0.025:
			status_label.text = "A manual vertex already exists there."
			return
	vertices.append(local_position)
	_commit_manual_vertices(owner_node, vertices, "Create connection vertex")
	status_label.text = "Connection vertex created and linked to the selected object."

func _move_manual_vertex(root: ModularBuilderPiece, old_world_position: Vector3, new_world_position: Vector3) -> void:
	var owner_record := _find_manual_vertex_record(root, old_world_position)
	if owner_record.is_empty():
		pending_points.clear()
		status_label.text = "The selected vertex is no longer available."
		return
	var owner_node: Node3D = owner_record.node
	var vertices: Array = owner_node.get_meta(CUSTOM_VERTICES_META, []).duplicate()
	vertices[owner_record.index] = owner_node.to_local(new_world_position)
	pending_points.clear()
	_commit_manual_vertices(owner_node, vertices, "Move connection vertex")
	status_label.text = "Vertex moved."

func _remove_manual_vertex(root: ModularBuilderPiece, world_position: Vector3) -> void:
	var owner_record := _find_manual_vertex_record(root, world_position)
	if owner_record.is_empty():
		return
	var owner_node: Node3D = owner_record.node
	var vertices: Array = owner_node.get_meta(CUSTOM_VERTICES_META, []).duplicate()
	vertices.remove_at(owner_record.index)
	_commit_manual_vertices(owner_node, vertices, "Remove connection vertex")
	status_label.text = "Vertex removed."

func _get_vertex_attachment_node(root: ModularBuilderPiece) -> Node3D:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.size() == 1:
		var selected_piece := selected[0] as ModularBuilderPiece
		if selected_piece != null and (selected_piece == root or _is_descendant_of_piece(selected_piece, root)):
			return selected_piece
		if selected[0] is ModularBuilderDetail and _is_descendant_of_piece(selected[0], root):
			return selected[0] as ModularBuilderDetail
	return root

func _find_manual_vertex_record(root: ModularBuilderPiece, world_position: Vector3) -> Dictionary:
	var owners: Array[Node3D] = []
	_collect_manual_vertex_owners(root, owners)
	var nearest_record := {}
	var nearest_distance := 0.05
	for owner_node in owners:
		var vertices: Array = owner_node.get_meta(CUSTOM_VERTICES_META, [])
		for i in range(vertices.size()):
			var local_point: Vector3 = vertices[i]
			var distance := owner_node.to_global(local_point).distance_to(world_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_record = {"node": owner_node, "index": i}
	return nearest_record
