@tool
extends RefCounted

# Find the roof outline from two diagonal corners at the top
# of parallel walls, even when the structure is rotated around Y.
static func find_corners(root: ModularBuilderPiece, first_world: Vector3, second_world: Vector3, allow_center: bool = false) -> PackedVector3Array:
	var first_edges := _matching_top_edges(root, first_world, allow_center)
	var second_edges := _matching_top_edges(root, second_world, allow_center)
	var best_corners := PackedVector3Array()
	var best_score := INF
	var best_length := 0.0
	for first_edge in first_edges:
		for second_edge in second_edges:
			if first_edge["wall"] == second_edge["wall"]:
				continue
			var a: Vector3 = first_edge["selected"]
			var adjacent_a: Vector3 = first_edge["other"]
			var c: Vector3 = second_edge["selected"]
			var adjacent_c: Vector3 = second_edge["other"]
			var edge_a := Vector2(adjacent_a.x - a.x, adjacent_a.z - a.z)
			var edge_c := Vector2(adjacent_c.x - c.x, adjacent_c.z - c.z)
			var length_a := edge_a.length()
			var length_c := edge_c.length()
			if length_a < 0.2 or length_c < 0.2:
				continue
			if edge_a.normalized().dot(edge_c.normalized()) > -0.9:
				continue
			var center_a := (a + adjacent_a) * 0.5
			var center_c := (c + adjacent_c) * 0.5
			if Vector2(center_c.x - center_a.x, center_c.z - center_a.z).length() < 0.2:
				continue
			var diagonal_error := (a + c - adjacent_a - adjacent_c).length()
			var length_error := absf(length_a - length_c)
			var tolerance := maxf(0.12, maxf(first_edge["thickness"], second_edge["thickness"]) * 0.5)
			if diagonal_error > tolerance or length_error > tolerance:
				continue
			var score := diagonal_error + length_error
			if score < best_score - 0.01 or (absf(score - best_score) <= 0.01 and length_a > best_length):
				best_score = score
				best_length = length_a
				best_corners = PackedVector3Array([a, adjacent_a, c, adjacent_c])
	return best_corners

static func _matching_top_edges(root: ModularBuilderPiece, world_point: Vector3, allow_center: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var walls: Array[ModularBuilderPiece] = []
	_collect_walls(root, walls)
	for wall in walls:
		var endpoints: PackedVector3Array = wall.call("_get_centered_wall_points") if wall.center_align else wall.custom_points
		if endpoints.size() < 2:
			continue
		var direction := endpoints[1] - endpoints[0]
		var horizontal := Vector2(direction.x, direction.z)
		if horizontal.length() < 0.2:
			continue
		var side := Vector3(-horizontal.y, 0.0, horizontal.x).normalized() * wall.thickness * 0.5
		for offset in [side, -side]:
			var top_a := wall.to_global(endpoints[0] + Vector3.UP * wall.unit_size + offset)
			var top_b := wall.to_global(endpoints[1] + Vector3.UP * wall.unit_size + offset)
			var center_a := wall.to_global(endpoints[0] + Vector3.UP * wall.unit_size)
			var center_b := wall.to_global(endpoints[1] + Vector3.UP * wall.unit_size)
			if top_a.distance_to(world_point) <= 0.08 or (allow_center and center_a.distance_to(world_point) <= 0.08):
				result.append({"wall": wall, "selected": root.to_local(top_a), "other": root.to_local(top_b), "thickness": wall.thickness})
			if top_b.distance_to(world_point) <= 0.08 or (allow_center and center_b.distance_to(world_point) <= 0.08):
				result.append({"wall": wall, "selected": root.to_local(top_b), "other": root.to_local(top_a), "thickness": wall.thickness})
	return result

static func _collect_walls(node: Node, result: Array[ModularBuilderPiece]) -> void:
	if node is ModularBuilderPiece and node.piece_type == ModularBuilderPiece.PieceType.WALL:
		result.append(node)
	for child in node.get_children():
		_collect_walls(child, result)
