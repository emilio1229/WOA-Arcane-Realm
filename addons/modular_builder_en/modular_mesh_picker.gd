@tool
extends RefCounted

static func raycast(root: Node3D, camera: Camera3D, screen_position: Vector2) -> Variant:
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position).normalized()
	var nearest_point: Variant = null
	var nearest_distance := INF
	var mesh_nodes: Array[MeshInstance3D] = []
	_collect_mesh_instances(root, mesh_nodes)
	for mesh_node in mesh_nodes:
		var source_mesh := mesh_node.mesh
		if source_mesh == null or not mesh_node.is_visible_in_tree():
			continue
		for surface_index in range(source_mesh.get_surface_count()):
			var arrays: Array
			if source_mesh is PrimitiveMesh:
				if surface_index > 0:
					continue
				arrays = source_mesh.get_mesh_arrays()
			else:
				if source_mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
					continue
				arrays = source_mesh.surface_get_arrays(surface_index)
			if arrays.is_empty() or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
				indices = arrays[Mesh.ARRAY_INDEX]
			var has_indices := not indices.is_empty()
			var triangle_count := indices.size() if has_indices else vertices.size()
			for triangle_start in range(0, triangle_count - 2, 3):
				var index_a := indices[triangle_start] if has_indices else triangle_start
				var index_b := indices[triangle_start + 1] if has_indices else triangle_start + 1
				var index_c := indices[triangle_start + 2] if has_indices else triangle_start + 2
				if index_a < 0 or index_b < 0 or index_c < 0 or index_a >= vertices.size() or index_b >= vertices.size() or index_c >= vertices.size():
					continue
				var vertex_a := mesh_node.to_global(vertices[index_a])
				var vertex_b := mesh_node.to_global(vertices[index_b])
				var vertex_c := mesh_node.to_global(vertices[index_c])
				var hit: Variant = Geometry3D.ray_intersects_triangle(ray_origin, ray_direction, vertex_a, vertex_b, vertex_c)
				if hit == null:
					continue
				var distance := ray_origin.distance_to(hit)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest_point = hit
	return nearest_point

static func _collect_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, result)
