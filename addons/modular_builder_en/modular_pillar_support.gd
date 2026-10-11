@tool
extends RefCounted

static func vertical_direction_for_piece(piece: ModularBuilderPiece, world_anchor: Vector3) -> Vector3:
	var local_anchor := piece.to_local(world_anchor)
	var low_y := 0.0
	var high_y := piece.unit_size
	match piece.piece_type:
		ModularBuilderPiece.PieceType.FOUNDATION_SQUARE, ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE:
			low_y = -piece.thickness * 0.5 if piece.centered_origin else 0.0
			high_y = piece.thickness * 0.5 if piece.centered_origin else piece.thickness
		ModularBuilderPiece.PieceType.FLOOR:
			high_y = piece.custom_points[0].y if not piece.custom_points.is_empty() else (piece.thickness * 0.5 if piece.centered_origin else piece.thickness)
			low_y = high_y - piece.thickness
		ModularBuilderPiece.PieceType.GABLE_WALL, ModularBuilderPiece.PieceType.GABLE_WALL_RIGHT:
			if piece.custom_points.size() >= 2:
				var base_points: PackedVector3Array = piece.call("_get_centered_gable_base") if piece.center_align else piece.custom_points
				low_y = base_points[0].y
				high_y = low_y + piece.rise
		_:
			if piece.custom_points.size() >= 2:
				var nearest_endpoint := piece.custom_points[0]
				var nearest_horizontal := INF
				for endpoint in piece.custom_points:
					var horizontal := Vector2(endpoint.x - local_anchor.x, endpoint.z - local_anchor.z).length_squared()
					if horizontal < nearest_horizontal:
						nearest_horizontal = horizontal
						nearest_endpoint = endpoint
				low_y = nearest_endpoint.y
				high_y = nearest_endpoint.y + piece.unit_size
	return Vector3.DOWN if absf(local_anchor.y - low_y) < absf(local_anchor.y - high_y) else Vector3.UP

static func vertical_direction_for_pillar(pillar: ModularBuilderDetail, world_anchor: Vector3) -> Vector3:
	return Vector3.DOWN if pillar.to_local(world_anchor).y < 0.0 else Vector3.UP
