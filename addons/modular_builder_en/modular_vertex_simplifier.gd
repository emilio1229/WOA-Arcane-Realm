@tool
extends RefCounted

static func piece_vertex(piece: ModularBuilderPiece, world_point: Vector3) -> Vector3:
	var local := piece.to_local(world_point)
	match piece.piece_type:
		ModularBuilderPiece.PieceType.FOUNDATION_SQUARE, ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE:
			local.y = piece.thickness * 0.5 if piece.centered_origin else piece.thickness
		ModularBuilderPiece.PieceType.FLOOR:
			if not piece.custom_points.is_empty():
				local.y = piece.custom_points[0].y
		ModularBuilderPiece.PieceType.WALL, ModularBuilderPiece.PieceType.GABLE_WALL, ModularBuilderPiece.PieceType.GABLE_WALL_RIGHT:
			var endpoints: PackedVector3Array
			if piece.piece_type == ModularBuilderPiece.PieceType.WALL:
				endpoints = piece.call("_get_centered_wall_points") if piece.center_align else piece.custom_points
			else:
				endpoints = piece.call("_get_centered_gable_base") if piece.center_align else piece.custom_points
			if endpoints.size() >= 2:
				var start := Vector2(endpoints[0].x, endpoints[0].z)
				var edge := Vector2(endpoints[1].x, endpoints[1].z) - start
				if edge.length_squared() > 0.000001:
					var fraction := clampf((Vector2(local.x, local.z) - start).dot(edge) / edge.length_squared(), 0.0, 1.0)
					var center := start + edge * fraction
					local.x = center.x
					local.z = center.y
	return piece.to_global(local)

static func pillar_vertex(pillar: ModularBuilderDetail, world_point: Vector3) -> Vector3:
	var local := pillar.to_local(world_point)
	local.x = 0.0
	local.z = 0.0
	return pillar.to_global(local)
