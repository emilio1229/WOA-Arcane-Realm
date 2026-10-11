@tool
extends "res://addons/modular_builder_en/modular_builder_editor_ui.gd"

func _add_piece() -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or not root is Node3D:
		status_label.text = "Open a 3D scene before adding a piece."
		return
	var piece := Node3D.new()
	piece.name = "ModularBuilderPiece"
	piece.set_script(PIECE_SCRIPT)
	piece.set("piece_type", ModularBuilderPiece.PieceType.BUILDING)
	var module_size_units := _meters_to_godot_units(size_spin.value)
	piece.set("unit_size", module_size_units)
	var foundation := Node3D.new()
	foundation.name = "Foundation"
	foundation.set_script(PIECE_SCRIPT)
	var chosen_type := _foundation_type_selected
	if chosen_type == 1:
		foundation.set("piece_type", ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE)
	else:
		foundation.set("piece_type", ModularBuilderPiece.PieceType.FOUNDATION_SQUARE)
	foundation.set("unit_size", module_size_units)
	foundation.set("centered_origin", true)
	foundation.position.y = foundation.thickness * 0.5
	piece.add_child(foundation, true)
	foundation.owner = root
	var undo := get_undo_redo()
	undo.create_action("Add ModularBuilderPiece")
	undo.add_do_method(root, "add_child", piece, true)
	undo.add_do_property(piece, "owner", root)
	undo.add_do_property(foundation, "owner", root)
	undo.add_undo_method(root, "remove_child", piece)
	undo.add_do_method(get_editor_interface().get_selection(), "clear")
	undo.add_do_method(get_editor_interface().get_selection(), "add_node", piece)
	undo.commit_action()
	_last_created_piece = foundation
	_active_button_key = TOOL_FOUNDATION_TRIANGLE if _foundation_type_selected == ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE else TOOL_FOUNDATION_SQUARE
	_set_tool(TOOL_FOUNDATION)

func _meters_to_godot_units(meters: float) -> float:
	return meters * METERS_TO_GODOT_UNITS

func _show_save_module_dialog() -> void:
	var building := _get_selected_piece()
	if building == null:
		status_label.text = "Select a ModularBuilderPiece structure to save as a module."
		return
	_save_module_dialog.current_file = "%s.tscn" % building.name
	_save_module_dialog.popup_centered_ratio(0.7)

func _show_load_module_dialog() -> void:
	_load_module_dialog.popup_centered_ratio(0.7)

func _on_export_pressed() -> void:
	var building := _get_selected_piece()
	if building == null:
		status_label.text = "Select a ModularBuilderPiece to export."
		return
	var baked_mesh := _bake_building_mesh(building)
	if baked_mesh == null or baked_mesh.get_surface_count() == 0:
		status_label.text = "No visible meshes were found to export."
		return
	if _export_mode_option.get_selected_id() == EXPORT_SCENE_COPY:
		_add_baked_copy(building, baked_mesh)
		return
	_pending_export_mesh = baked_mesh
	_pending_export_name = "%s_Baked" % building.name
	_pending_export_basis = building.global_transform.basis
	_export_scene_dialog.current_file = "%s.tscn" % _pending_export_name
	_export_scene_dialog.popup_centered_ratio(0.7)

func _bake_building_mesh(building: ModularBuilderPiece) -> ArrayMesh:
	return MESH_BAKER.new().bake(building)

func _add_baked_copy(building: ModularBuilderPiece, mesh: ArrayMesh) -> void:
	var edited_scene_root := get_editor_interface().get_edited_scene_root()
	if edited_scene_root == null or building.get_parent() == null:
		status_label.text = "Open a scene before adding the exported copy."
		return
	var sibling_parent := building.get_parent()
	var baked_root := _make_baked_scene_root(building.name + "_Baked", mesh)
	var undo := get_undo_redo()
	undo.create_action("Export structure as a mesh copy")
	undo.add_do_method(self, "_attach_baked_copy", sibling_parent, edited_scene_root, baked_root, building.global_transform)
	undo.add_undo_method(self, "_detach_baked_copy", sibling_parent, baked_root)
	undo.commit_action()
	status_label.text = "Copy exported as one mesh with %d material surface(s). Ctrl+Z removes the copy." % mesh.get_surface_count()

func _attach_baked_copy(sibling_parent: Node, edited_scene_root: Node, baked_root: Node3D, target_transform: Transform3D) -> void:
	if baked_root.get_parent() != sibling_parent:
		if baked_root.get_parent() != null:
			baked_root.get_parent().remove_child(baked_root)
		sibling_parent.add_child(baked_root, true)
	baked_root.global_transform = target_transform
	baked_root.owner = edited_scene_root
	_set_export_owner_recursive(baked_root, edited_scene_root)
	var editor_selection := get_editor_interface().get_selection()
	editor_selection.clear()
	editor_selection.add_node(baked_root)

func _detach_baked_copy(sibling_parent: Node, baked_root: Node3D) -> void:
	if baked_root.get_parent() == sibling_parent:
		sibling_parent.remove_child(baked_root)

func _make_baked_scene_root(root_name: String, mesh: ArrayMesh) -> Node3D:
	var baked_root := Node3D.new()
	baked_root.name = root_name
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "BakedMesh"
	mesh_instance.mesh = mesh
	baked_root.add_child(mesh_instance)
	return baked_root

func _export_baked_scene_to_path(path: String) -> void:
	if _pending_export_mesh == null:
		status_label.text = "The exported mesh is no longer available. Bake it again."
		return
	var baked_root := _make_baked_scene_root(_pending_export_name, _pending_export_mesh)
	baked_root.transform = Transform3D(_pending_export_basis, Vector3.ZERO)
	_set_export_owner_recursive(baked_root, baked_root)
	var packed := PackedScene.new()
	var pack_error := packed.pack(baked_root)
	baked_root.free()
	if pack_error != OK:
		status_label.text = "Could not pack the exported mesh (%s)." % error_string(pack_error)
		return
	var save_error := ResourceSaver.save(packed, path)
	if save_error != OK:
		status_label.text = "Could not save the exported scene (%s)." % error_string(save_error)
		return
	get_editor_interface().get_resource_filesystem().scan()
	status_label.text = "Exported scene: %s (%d material surface(s))." % [path, _pending_export_mesh.get_surface_count()]
	_pending_export_mesh = null

func _set_export_owner_recursive(node: Node, scene_owner: Node) -> void:
	for child in node.get_children():
		child.owner = scene_owner
		_set_export_owner_recursive(child, scene_owner)

func _save_module_to_path(path: String) -> void:
	var building := _get_selected_piece()
	if building == null:
		status_label.text = "Select a ModularBuilderPiece structure to save as a module."
		return
	var descendants: Array[Node] = []
	_collect_module_nodes(building, descendants)
	var original_owners: Dictionary = {}
	for node in descendants:
		original_owners[node] = node.owner
		node.owner = building
	var packed := PackedScene.new()
	var pack_error := packed.pack(building)
	for node in descendants:
		node.owner = original_owners[node]
	if pack_error != OK:
		status_label.text = "Could not pack the structure as a scene (%s)." % error_string(pack_error)
		return
	var save_error := ResourceSaver.save(packed, path)
	if save_error != OK:
		status_label.text = "Could not save the module (%s)." % error_string(save_error)
		return
	status_label.text = "Module saved: %s" % path

func _collect_module_nodes(node: Node, result: Array[Node]) -> void:
	for child in node.get_children():
		if child.name == "ModularBuilderMarkers" or child.has_meta("modular_builder_preview"):
			continue
		result.append(child)
		_collect_module_nodes(child, result)

func _load_module_from_path(path: String) -> void:
	var packed := ResourceLoader.load(path) as PackedScene
	if packed == null:
		status_label.text = "The selected file is not a valid Godot scene."
		return
	var instance := packed.instantiate()
	if not instance is Node3D:
		instance.free()
		status_label.text = "The module scene must have a Node3D root."
		return
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		instance.free()
		status_label.text = "Open a scene before inserting a module."
		return
	var anchor := _get_selected_piece()
	if anchor != null:
		var target_world := anchor.global_position + anchor.global_transform.basis.x * maxf(anchor.unit_size, 1.0)
		instance.position = scene_root.to_local(target_world)
	var undo := get_undo_redo()
	undo.create_action("Insert module %s" % instance.name)
	undo.add_do_method(self, "_attach_module", scene_root, instance)
	undo.add_undo_method(self, "_detach_module", scene_root, instance)
	undo.commit_action()
	status_label.text = "Module inserted. Move the piece to the desired location."

func _attach_module(scene_root: Node, instance: Node) -> void:
	if instance.get_parent() != scene_root:
		scene_root.add_child(instance, true)
	instance.owner = scene_root
	var editor_selection := get_editor_interface().get_selection()
	editor_selection.clear()
	editor_selection.add_node(instance)

func _detach_module(scene_root: Node, instance: Node) -> void:
	if instance.get_parent() == scene_root:
		scene_root.remove_child(instance)

func _rotate_selected_piece() -> void:
	var selected_piece := _raw_selected_piece()
	var target := selected_piece
	if selected_piece == null:
		target = _last_created_piece if is_instance_valid(_last_created_piece) and _last_created_piece.is_inside_tree() else null
	elif selected_piece.piece_type == ModularBuilderPiece.PieceType.BUILDING:
		target = null
		if is_instance_valid(_last_created_piece) and _last_created_piece.is_inside_tree() and _is_descendant_of(_last_created_piece, selected_piece):
			target = _last_created_piece
	if target == null:
		status_label.text = "Select or create a piece to rotate."
		return
	var old_rotation := target.rotation_degrees
	var undo := get_undo_redo()
	undo.create_action("Rotate piece 90 degrees")
	undo.add_do_property(target, "rotation_degrees", old_rotation + Vector3(0.0, 90.0, 0.0))
	undo.add_undo_property(target, "rotation_degrees", old_rotation)
	undo.commit_action()
	_last_created_piece = target
	status_label.text = "%s rotated by 90°." % target.name
	update_overlays()

func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false

func _raw_selected_piece() -> ModularBuilderPiece:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.size() == 1 and selected[0] is ModularBuilderPiece:
		return selected[0] as ModularBuilderPiece
	return null

func _add_general_collision() -> void:
	var piece := _get_selected_piece()
	if piece == null:
		status_label.text = "Select a structure to generate general collision."
		return
	var scene_root := get_editor_interface().get_edited_scene_root()
	var faces := PackedVector3Array()
	var structure_pieces: Array[ModularBuilderPiece] = []
	_collect_structure_pieces(piece, structure_pieces)
	_collect_scene_pieces(scene_root, structure_pieces)
	_collect_collision_faces(piece, piece, faces, {}, structure_pieces)
	if faces.is_empty():
		status_label.text = "The selected structure has no geometry for collision."
		return
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(faces)
	var body := piece.find_child("GeneralCollision", true, false) as StaticBody3D
	var undo := get_undo_redo()
	if body != null:
		var shape_node := body.get_node_or_null("Shape") as CollisionShape3D
		if shape_node == null:
			shape_node = CollisionShape3D.new()
			shape_node.name = "Shape"
			shape_node.shape = concave
			undo.create_action("Add shape to general collision")
			undo.add_do_method(body, "add_child", shape_node, true)
			undo.add_do_property(shape_node, "owner", scene_root)
			undo.add_undo_method(body, "remove_child", shape_node)
		else:
			var old_shape: Shape3D = shape_node.shape
			undo.create_action("Update general collision")
			undo.add_do_property(shape_node, "shape", concave)
			undo.add_undo_property(shape_node, "shape", old_shape)
	else:
		body = StaticBody3D.new()
		body.name = "GeneralCollision"
		var shape_node := CollisionShape3D.new()
		shape_node.name = "Shape"
		shape_node.shape = concave
		body.add_child(shape_node)
		undo.create_action("Add general collision")
		undo.add_do_method(piece, "add_child", body, true)
		undo.add_do_property(body, "owner", scene_root)
		undo.add_do_property(shape_node, "owner", scene_root)
		undo.add_undo_method(piece, "remove_child", body)
	undo.commit_action()
	status_label.text = "General collision added or updated. Snap markers are excluded."

func _collect_structure_pieces(node: Node, pieces: Array[ModularBuilderPiece]) -> void:
	if node is ModularBuilderPiece:
		pieces.append(node)
	for child in node.get_children():
		if child.name == "ModularBuilderMarkers" or child.name == "GeneralCollision":
			continue
		_collect_structure_pieces(child, pieces)

func _collect_scene_pieces(node: Node, pieces: Array[ModularBuilderPiece]) -> void:
	if node is ModularBuilderPiece and not pieces.has(node):
		pieces.append(node)
	for child in node.get_children():
		if child.name == "ModularBuilderMarkers" or child.name == "GeneralCollision":
			continue
		_collect_scene_pieces(child, pieces)

func _collect_collision_faces(node: Node, piece_root: ModularBuilderPiece, faces: PackedVector3Array, seen_faces: Dictionary, structure_pieces: Array[ModularBuilderPiece]) -> void:
	if node is MeshInstance3D and node.name == "Geometry" and node.mesh != null:
		var relative_transform: Transform3D = piece_root.global_transform.affine_inverse() * node.global_transform
		var mesh_faces: PackedVector3Array = node.mesh.get_faces()
		var owner_piece := node.get_parent() as ModularBuilderPiece
		for i in range(0, mesh_faces.size(), 3):
			if i + 2 >= mesh_faces.size():
				break
			var local_a: Vector3 = mesh_faces[i]
			var local_b: Vector3 = mesh_faces[i + 1]
			var local_c: Vector3 = mesh_faces[i + 2]
			if _is_connection_face(owner_piece, local_a, local_b, local_c, structure_pieces):
				continue
			# Procedural meshes have both sides. Deduplication may retain
			# either orientation; normalize top faces beforehand to
			# keep custom foundations navigable.
			if _is_piece_top_face(owner_piece, local_a, local_b, local_c):
				if (local_b - local_a).cross(local_c - local_a).y < 0.0:
					var swap := local_b
					local_b = local_c
					local_c = swap
			var a: Vector3 = relative_transform * local_a
			var b: Vector3 = relative_transform * local_b
			var c: Vector3 = relative_transform * local_c
			var key_parts := [_collision_vertex_key(a), _collision_vertex_key(b), _collision_vertex_key(c)]
			key_parts.sort()
			var face_key := "%s|%s|%s" % key_parts
			if seen_faces.has(face_key):
				continue
			seen_faces[face_key] = true
			faces.append_array(PackedVector3Array([a, b, c]))
	for child in node.get_children():
		if child.name == "ModularBuilderMarkers" or child.name == "GeneralCollision":
			continue
		_collect_collision_faces(child, piece_root, faces, seen_faces, structure_pieces)

func _is_piece_top_face(piece: ModularBuilderPiece, a: Vector3, b: Vector3, c: Vector3) -> bool:
	if piece == null:
		return false
	if piece.piece_type != ModularBuilderPiece.PieceType.FLOOR and piece.piece_type != ModularBuilderPiece.PieceType.FOUNDATION_SQUARE and piece.piece_type != ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE:
		return false
	if absf(a.y - b.y) > 0.002 or absf(a.y - c.y) > 0.002:
		return false
	var top_y := piece.thickness * 0.5 if piece.centered_origin else piece.thickness
	if piece.piece_type == ModularBuilderPiece.PieceType.FLOOR and piece.custom_points.size() >= 3:
		top_y = piece.custom_points[0].y
	return absf(a.y - top_y) < 0.002 and absf(b.y - top_y) < 0.002 and absf(c.y - top_y) < 0.002

func _is_connection_face(piece: ModularBuilderPiece, a: Vector3, b: Vector3, c: Vector3, structure_pieces: Array[ModularBuilderPiece]) -> bool:
	if piece == null:
		return false
	if (piece.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_SQUARE or piece.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE) and _foundation_edge_is_shared(piece, a, b, c, structure_pieces):
		return true
	if piece.piece_type == ModularBuilderPiece.PieceType.FLOOR and piece.custom_points.size() >= 3:
		var bottom_point := piece.custom_points[0] - Vector3.UP * piece.thickness
		return _triangle_on_plane(a, b, c, bottom_point, Vector3.UP)
	if piece.piece_type != ModularBuilderPiece.PieceType.WALL or piece.custom_points.size() < 2:
		return false
	var start: Vector3 = piece.custom_points[0]
	var finish: Vector3 = piece.custom_points[1]
	var direction := (finish - start).normalized()
	var side := Vector3(-direction.z, 0.0, direction.x).normalized() * piece.thickness * 0.5
	var base_normal := (finish - start).cross(side).normalized()
	if _triangle_on_plane(a, b, c, start, base_normal):
		return true
	if _wall_has_floor_contact(piece, structure_pieces):
		if _triangle_on_plane(a, b, c, start + Vector3.UP * piece.unit_size, base_normal):
			return true
	for other in structure_pieces:
		if other == piece or other.piece_type != ModularBuilderPiece.PieceType.WALL or other.custom_points.size() < 2:
			continue
		for endpoint in piece.custom_points:
			var endpoint_world := piece.to_global(endpoint)
			for other_endpoint in other.custom_points:
				if endpoint_world.distance_to(other.to_global(other_endpoint)) < 0.02:
					var local_endpoint := piece.to_local(endpoint_world)
					if _triangle_on_plane(a, b, c, local_endpoint, direction):
						return true
	return false

func _wall_has_floor_contact(wall: ModularBuilderPiece, structure_pieces: Array[ModularBuilderPiece]) -> bool:
	var endpoints: PackedVector3Array = wall.custom_points
	var direction := (endpoints[1] - endpoints[0]).normalized()
	var side := Vector3(-direction.z, 0.0, direction.x).normalized() * wall.thickness * 0.5
	for endpoint in endpoints:
		var top := endpoint + Vector3.UP * wall.unit_size
		for wall_corner in [wall.to_global(top + side), wall.to_global(top - side)]:
			for other in structure_pieces:
				if other.piece_type != ModularBuilderPiece.PieceType.FLOOR or other.custom_points.size() < 3:
					continue
				for floor_point in other.custom_points:
					if wall_corner.distance_to(other.to_global(floor_point)) < 0.02:
						return true
	return false

func _foundation_edge_is_shared(piece: ModularBuilderPiece, a: Vector3, b: Vector3, c: Vector3, structure_pieces: Array[ModularBuilderPiece]) -> bool:
	var polygon := _foundation_polygon(piece)
	for other in structure_pieces:
		if other == piece or (other.piece_type != ModularBuilderPiece.PieceType.FOUNDATION_SQUARE and other.piece_type != ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE):
			continue
		var other_polygon := _foundation_polygon(other)
		for i in range(polygon.size()):
			var p0: Vector2 = polygon[i]
			var p1: Vector2 = polygon[(i + 1) % polygon.size()]
			for j in range(other_polygon.size()):
				var q0: Vector2 = other_polygon[j]
				var q1: Vector2 = other_polygon[(j + 1) % other_polygon.size()]
				var other_base_y := -other.thickness * 0.5 if other.centered_origin else 0.0
				var q0_local := piece.to_local(other.to_global(Vector3(q0.x, other_base_y, q0.y)))
				var q1_local := piece.to_local(other.to_global(Vector3(q1.x, other_base_y, q1.y)))
				var shared := _segments_overlap(p0, p1, Vector2(q0_local.x, q0_local.z), Vector2(q1_local.x, q1_local.z))
				var piece_base_y := -piece.thickness * 0.5 if piece.centered_origin else 0.0
				if shared and absf(q0_local.y - piece_base_y) < 0.02 and absf(q1_local.y - piece_base_y) < 0.02 and _triangle_on_edge(a, b, c, p0, p1):
					return true
	return false

func _triangle_on_edge(a: Vector3, b: Vector3, c: Vector3, edge_a: Vector2, edge_b: Vector2) -> bool:
	return _point_on_edge(Vector2(a.x, a.z), edge_a, edge_b) and _point_on_edge(Vector2(b.x, b.z), edge_a, edge_b) and _point_on_edge(Vector2(c.x, c.z), edge_a, edge_b)

func _point_on_edge(point: Vector2, edge_a: Vector2, edge_b: Vector2) -> bool:
	var edge := edge_b - edge_a
	var length_squared := edge.length_squared()
	if length_squared < 0.000001:
		return false
	var t := (point - edge_a).dot(edge) / length_squared
	var closest := edge_a + edge * clampf(t, 0.0, 1.0)
	return t >= -0.002 and t <= 1.002 and point.distance_to(closest) < 0.002

func _segments_overlap(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var direction := b - a
	var length := direction.length()
	if length < 0.0001:
		return false
	var unit := direction / length
	if absf(unit.x * (c - a).y - unit.y * (c - a).x) > 0.02 or absf(unit.x * (d - a).y - unit.y * (d - a).x) > 0.02:
		return false
	var c_proj := (c - a).dot(unit)
	var d_proj := (d - a).dot(unit)
	var overlap := minf(length, maxf(c_proj, d_proj)) - maxf(0.0, minf(c_proj, d_proj))
	return overlap > 0.02

func _triangle_on_plane(a: Vector3, b: Vector3, c: Vector3, plane_point: Vector3, plane_normal: Vector3) -> bool:
	if plane_normal.length_squared() < 0.000001:
		return false
	var normal := plane_normal.normalized()
	return absf((a - plane_point).dot(normal)) < 0.002 and absf((b - plane_point).dot(normal)) < 0.002 and absf((c - plane_point).dot(normal)) < 0.002

func _collision_vertex_key(point: Vector3) -> String:
	return "%.4f,%.4f,%.4f" % [point.x, point.y, point.z]

func _set_tool(tool: String) -> void:
	active_tool = tool
	_detail_options_row.visible = _is_detail_tool(tool)
	_rise_options_row.visible = tool == TOOL_WALL or tool == TOOL_GABLE_WALL or tool == TOOL_GABLE_WALL_RIGHT or tool == TOOL_ROOF_GABLE or tool == TOOL_ROOF_PYRAMID
	_linear_options_row.visible = tool == TOOL_STAIRS or tool == TOOL_FENCE
	_stair_count_label.visible = tool == TOOL_STAIRS
	stair_count_spin.visible = tool == TOOL_STAIRS
	_stair_width_label.visible = tool == TOOL_STAIRS
	stair_width_spin.visible = tool == TOOL_STAIRS
	_fence_divisions_label.visible = tool == TOOL_FENCE
	fence_divisions_spin.visible = tool == TOOL_FENCE
	_gable_centralize_check.visible = tool == TOOL_WALL or tool == TOOL_GABLE_WALL or tool == TOOL_GABLE_WALL_RIGHT
	_rise_label.text = "Peak rise:"
	if not _is_detail_tool(tool):
		call("_clear_detail_preview")
	if tool == TOOL_NONE:
		_active_button_key = ""
	pending_points.clear()
	for button_tool in _tool_buttons:
		_tool_buttons[button_tool].set_pressed_no_signal(button_tool == _active_button_key)
	if tool == TOOL_NONE:
		status_label.text = "Tool deactivated."
	elif _get_selected_piece() == null:
		status_label.text = "Select the corresponding piece in the Scene tree."
	elif tool == TOOL_FOUNDATION:
		status_label.text = "Click a + button beside any foundation. Click the tool again to deactivate it."
	elif tool == TOOL_WINDOW or tool == TOOL_DOOR:
		status_label.text = "Click a wall face to insert the detail. Edit its mode and dimensions in the Inspector."
	elif tool == TOOL_HATCH:
		status_label.text = "Click a foundation or floor face to insert the hatch. Edit it in the Inspector."
	elif tool == TOOL_GABLE_WALL:
		status_label.text = "Click the two base vertices of the gable. Adjust peak height below."
	elif tool == TOOL_GABLE_WALL_RIGHT:
		status_label.text = "Click the base vertices; the second point sets the high side of the right triangular gable."
	elif tool == TOOL_WALL:
		status_label.text = "Click two vertices on foundations, floors, or wall tops. Enable Center walls to align the endpoints with supporting walls."
	elif tool == TOOL_ROOF_GABLE:
		status_label.text = "Click the peaks of two gables or diagonal corners atop opposite walls."
	elif tool == TOOL_ROOF_SHED:
		status_label.text = "Click a low point, then a diagonally opposite high point. The roof finds the other corners; adjust width in the Inspector."
	elif tool == TOOL_ROOF_PYRAMID:
		status_label.text = "Click two diagonal vertices at the same height. Adjust pyramid peak height below or in the Inspector."
	elif tool == TOOL_STAIRS:
		status_label.text = "Click the low point, then the high point to create stairs. Adjust steps and width below."
	elif tool == TOOL_FENCE or tool == TOOL_PARAPET:
		status_label.text = "Click two vertices to set the path. Adjust height and intermediate posts below."
	elif tool == TOOL_MERGE_VERTICES:
		status_label.text = "Click two vertices to merge their markers. Ctrl+Z undoes the merge."
	elif tool == TOOL_CREATE_VERTEX:
		status_label.text = "Click a surface to create a connection point linked to the selected piece or detail."
	elif tool == TOOL_MOVE_VERTEX:
		status_label.text = "Click a blue manual point, then the surface where you want to move it."
	elif tool == TOOL_REMOVE_VERTEX:
		status_label.text = "Click a blue manual point to remove it."
	elif tool == TOOL_PILLAR:
		status_label.text = "Click two vertices to connect them. Alt+click one vertex to create a vertical pillar with the panel length."
	else:
		status_label.text = "Click the blue structure vertices. Click the tool again to deactivate it."
	call("_sync_vertex_markers")
	update_overlays()

func _get_selected_piece() -> ModularBuilderPiece:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.is_empty():
		return null
	var common_root: ModularBuilderPiece
	for selected_node in selected:
		var selected_piece := selected_node as ModularBuilderPiece
		if selected_piece == null and selected_node is ModularBuilderDetail:
			var parent := selected_node.get_parent()
			while parent != null and not parent is ModularBuilderPiece:
				parent = parent.get_parent()
			selected_piece = parent as ModularBuilderPiece
		if selected_piece == null:
			return null
		var piece_root := selected_piece
		var ancestor := selected_piece.get_parent()
		while ancestor != null:
			if ancestor is ModularBuilderPiece and ancestor.piece_type == ModularBuilderPiece.PieceType.BUILDING:
				piece_root = ancestor
				break
			ancestor = ancestor.get_parent()
		if common_root == null:
			common_root = piece_root
		elif common_root != piece_root:
			return null
	return common_root

func _on_editor_selection_changed() -> void:
	if _redirecting_selection:
		return
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	var redirected_selection: Array[Node] = []
	var needs_redirect := false
	for selected_node in selected:
		var target_node: Node = selected_node
		if selected_node is MeshInstance3D:
			var ancestor := selected_node.get_parent()
			while ancestor != null and not (ancestor is ModularBuilderPiece or ancestor is ModularBuilderDetail):
				ancestor = ancestor.get_parent()
			if ancestor != null:
				target_node = ancestor
				needs_redirect = true
		if not redirected_selection.has(target_node):
			redirected_selection.append(target_node)
	if needs_redirect:
		_redirecting_selection = true
		var editor_selection := get_editor_interface().get_selection()
		editor_selection.clear()
		for target_node in redirected_selection:
			editor_selection.add_node(target_node)
		_redirecting_selection = false
	if active_tool != TOOL_NONE:
		pending_points.clear()
	_sync_pillar_centralize_control()
	call("_sync_vertex_markers")
	update_overlays()

func _on_marker_scope_toggled(_enabled: bool) -> void:
	call("_sync_vertex_markers")
	update_overlays()

func _on_simplify_vertices_toggled(_enabled: bool) -> void:
	pending_points.clear()
	call("_sync_vertex_markers")
	update_overlays()

func _foundation_polygon(root: ModularBuilderPiece) -> Array[Vector2]:
	if root.custom_points.size() >= 3:
		var custom: Array[Vector2] = []
		for point in root.custom_points:
			custom.append(Vector2(point.x, point.z))
		return custom
	var half := root.unit_size * 0.5
	if root.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE:
		return [Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half)]
	return [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
