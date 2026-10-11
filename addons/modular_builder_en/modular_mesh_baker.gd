@tool
extends RefCounted

func bake(building: ModularBuilderPiece) -> ArrayMesh:
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(building, mesh_instances)
	var groups: Array[Dictionary] = []
	var projected_materials: Dictionary = {}
	for mesh_instance in mesh_instances:
		if not is_instance_valid(mesh_instance) or not mesh_instance.is_visible_in_tree() or _is_export_excluded(mesh_instance, building):
			continue
		var source_mesh := mesh_instance.mesh
		if source_mesh == null:
			continue
		var relative_transform := building.global_transform.affine_inverse() * mesh_instance.global_transform
		if absf(relative_transform.basis.determinant()) < 0.000001:
			continue
		var normal_transform := relative_transform.basis.inverse().transposed()
		var mirrored := relative_transform.basis.determinant() < 0.0
		for surface_index in range(source_mesh.get_surface_count()):
			var primitive_type := Mesh.PRIMITIVE_TRIANGLES
			var surface_arrays: Array
			if source_mesh is PrimitiveMesh:
				# PrimitiveMesh provides mesh arrays directly; surface_get_* methods
				# are used for other meshes.
				if surface_index > 0:
					continue
				surface_arrays = source_mesh.get_mesh_arrays()
			else:
				primitive_type = source_mesh.surface_get_primitive_type(surface_index)
				surface_arrays = source_mesh.surface_get_arrays(surface_index)
			if primitive_type != Mesh.PRIMITIVE_TRIANGLES:
				continue
			if surface_arrays.is_empty() or not surface_arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
				continue
			var source_vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
			if source_vertices.size() < 3:
				continue
			var source_normals := PackedVector3Array()
			var source_uvs := PackedVector2Array()
			var source_colors := PackedColorArray()
			if surface_arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
				source_normals = surface_arrays[Mesh.ARRAY_NORMAL]
			if surface_arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array:
				source_uvs = surface_arrays[Mesh.ARRAY_TEX_UV]
			if surface_arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
				source_colors = surface_arrays[Mesh.ARRAY_COLOR]
			var source_indices := PackedInt32Array()
			if surface_arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
				source_indices = surface_arrays[Mesh.ARRAY_INDEX]
			var material := mesh_instance.get_active_material(surface_index)
			var force_projected_uvs := false
			var bake_material := material
			if material is StandardMaterial3D and material.uv1_triplanar:
				force_projected_uvs = true
				var material_id := material.get_instance_id()
				if not projected_materials.has(material_id):
					var material_copy := material.duplicate() as StandardMaterial3D
					material_copy.uv1_triplanar = false
					material_copy.uv1_world_triplanar = false
					projected_materials[material_id] = material_copy
				bake_material = projected_materials[material_id] as Material
			var group_index := _find_or_create_group(groups, bake_material)
			var group: Dictionary = groups[group_index]
			var group_vertices: Array = group["vertices"]
			var group_normals: Array = group["normals"]
			var group_uvs: Array = group["uvs"]
			var group_colors: Array = group["colors"]
			var has_indices := not source_indices.is_empty()
			var triangle_count := source_indices.size() if has_indices else source_vertices.size()
			for triangle_start in range(0, triangle_count - 2, 3):
				var index_a := source_indices[triangle_start] if has_indices else triangle_start
				var index_b := source_indices[triangle_start + 1] if has_indices else triangle_start + 1
				var index_c := source_indices[triangle_start + 2] if has_indices else triangle_start + 2
				if index_a >= source_vertices.size() or index_b >= source_vertices.size() or index_c >= source_vertices.size():
					continue
				if mirrored:
					var swap_index := index_b
					index_b = index_c
					index_c = swap_index
				var local_a: Vector3 = source_vertices[index_a]
				var local_b: Vector3 = source_vertices[index_b]
				var local_c: Vector3 = source_vertices[index_c]
				var baked_a: Vector3 = relative_transform * local_a
				var baked_b: Vector3 = relative_transform * local_b
				var baked_c: Vector3 = relative_transform * local_c
				var face_normal := (baked_b - baked_a).cross(baked_c - baked_a).normalized()
				if face_normal.length_squared() < 0.5:
					continue
				var baked_points := [baked_a, baked_b, baked_c]
				var source_point_indices := [index_a, index_b, index_c]
				var source_face_normal := (local_b - local_a).cross(local_c - local_a).normalized()
				for corner in range(3):
					var source_index: int = source_point_indices[corner]
					var baked_point: Vector3 = baked_points[corner]
					var baked_normal := face_normal
					if source_normals.size() == source_vertices.size():
						baked_normal = (normal_transform * source_normals[source_index]).normalized()
					if baked_normal.length_squared() < 0.5:
						baked_normal = face_normal
					var uv: Vector2
					if not force_projected_uvs and source_uvs.size() == source_vertices.size():
						uv = source_uvs[source_index]
					else:
						uv = _project_uv(source_vertices[source_index], source_face_normal)
					var color := source_colors[source_index] if source_colors.size() == source_vertices.size() else Color.WHITE
					group_vertices.append(baked_point)
					group_normals.append(baked_normal)
					group_uvs.append(uv)
					group_colors.append(color)
			groups[group_index] = group
	if groups.is_empty():
		return null
	var combined := ArrayMesh.new()
	combined.resource_name = "%s_Mesh" % building.name
	for group in groups:
		var vertices := PackedVector3Array(group["vertices"])
		if vertices.is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(group["normals"])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(group["uvs"])
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray(group["colors"])
		var surface_tool := SurfaceTool.new()
		surface_tool.create_from_arrays(arrays, Mesh.PRIMITIVE_TRIANGLES)
		if group["material"] is Material:
			surface_tool.set_material(group["material"])
		surface_tool.generate_tangents()
		var temp_mesh := surface_tool.commit()
		if temp_mesh == null or temp_mesh.get_surface_count() == 0:
			continue
		combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, temp_mesh.surface_get_arrays(0))
		if group["material"] is Material:
			combined.surface_set_material(combined.get_surface_count() - 1, group["material"])
	return combined if combined.get_surface_count() > 0 else null

func _find_or_create_group(groups: Array[Dictionary], material: Material) -> int:
	for i in range(groups.size()):
		if groups[i]["material"] == material:
			return i
	groups.append({"material": material, "vertices": [], "normals": [], "uvs": [], "colors": []})
	return groups.size() - 1

func _project_uv(point: Vector3, normal: Vector3) -> Vector2:
	var absolute_normal := normal.abs()
	if absolute_normal.y >= absolute_normal.x and absolute_normal.y >= absolute_normal.z:
		return Vector2(point.x, point.z)
	if absolute_normal.x >= absolute_normal.z:
		return Vector2(point.z, point.y)
	return Vector2(point.x, point.y)

func _is_export_excluded(mesh_instance: MeshInstance3D, building: ModularBuilderPiece) -> bool:
	var current: Node = mesh_instance
	while current != null and current != building:
		if current.has_meta("modular_builder_preview") or current.name == "ModularBuilderMarkers":
			return true
		current = current.get_parent()
	return false

func _collect_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, result)
