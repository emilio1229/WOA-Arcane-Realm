@tool
class_name ModularBuilderPieceGeometry
extends Node3D

const DETAIL_SCRIPT_PATH := "res://addons/modular_builder_en/modular_building_detail.gd"
const DETAIL_TYPE_HATCH := 2
const DETAIL_TYPE_PILLAR := 3

enum PieceType { FOUNDATION_SQUARE, FOUNDATION_TRIANGLE, FLOOR, WALL, BUILDING, GABLE_WALL, ROOF_GABLE, ROOF_SHED, GABLE_WALL_RIGHT, ROOF_PYRAMID, STAIRS, FENCE }

@export var piece_type: PieceType = PieceType.FOUNDATION_SQUARE:
	set(value):
		piece_type = value
		notify_property_list_changed()
		_rebuild()
@export_range(0.5, 8.0, 0.001, "suffix:m") var unit_size: float = 2.0:
	set(value):
		unit_size = value
		_rebuild()
@export_range(0.01, 1.0, 0.001, "suffix:m") var thickness: float = 0.2:
	set(value):
		thickness = value
		_rebuild()
		for child in get_children():
			if child.has_method("_on_host_thickness_changed"):
				child.call("_on_host_thickness_changed")
@export_range(0.1, 8.0, 0.001, "suffix:m") var rise: float = 1.0:
	set(value):
		rise = value
		_rebuild()
@export_range(0.01, 32.0, 0.001, "suffix:m") var roof_width: float = 2.0:
	set(value):
		roof_width = value
		_rebuild()
@export_range(1, 100, 1, "suffix: steps") var stair_count: int = 10:
	set(value):
		stair_count = value
		_rebuild()
@export_range(0.01, 8.0, 0.001, "suffix:m") var stair_width: float = 1.0:
	set(value):
		stair_width = value
		_rebuild()
@export_range(0, 100, 1, "suffix: posts") var fence_divisions: int = 1:
	set(value):
		fence_divisions = value
		_rebuild()
@export_range(0.1, 8.0, 0.001, "suffix:m") var fence_height: float = 1.0:
	set(value):
		fence_height = value
		_rebuild()
@export var symmetric_dimensions: bool = true:
	set(value):
		if symmetric_dimensions == value:
			return
		if not value:
			_capture_mesh_dimensions()
		symmetric_dimensions = value
		notify_property_list_changed()
		if value:
			scale = Vector3.ONE
		else:
			_apply_dimension_scale()
@export_range(0.01, 100.0, 0.001, "suffix:m") var dimension_width: float = 2.0:
	set(value):
		dimension_width = value
		_apply_dimension_scale()
@export_range(0.01, 100.0, 0.001, "suffix:m") var dimension_height: float = 2.0:
	set(value):
		dimension_height = value
		_apply_dimension_scale()
@export_range(0.01, 100.0, 0.001, "suffix:m") var dimension_depth: float = 2.0:
	set(value):
		dimension_depth = value
		_apply_dimension_scale()
@export_storage var _dimension_reference: Vector3 = Vector3.ZERO
@export var center_align: bool = false:
	set(value):
		center_align = value
		_rebuild()
@export var surface_material: Material:
	set(value):
		surface_material = value
		_rebuild()
@export var custom_points: PackedVector3Array = PackedVector3Array():
	set(value):
		custom_points = value
		_rebuild()
@export var centered_origin: bool = false:
	set(value):
		centered_origin = value
		_rebuild()

func _rebuild() -> void:
	pass

func _capture_mesh_dimensions() -> void:
	var geometry := get_node_or_null("Geometry") as MeshInstance3D
	if geometry == null or geometry.mesh == null:
		return
	var dimensions := geometry.mesh.get_aabb().size
	if dimensions.x > 0.001:
		dimension_width = dimensions.x
	if dimensions.y > 0.001:
		dimension_height = dimensions.y
	if dimensions.z > 0.001:
		dimension_depth = dimensions.z
	_dimension_reference = dimensions

func _apply_dimension_scale() -> void:
	if symmetric_dimensions or _dimension_reference.x <= 0.001 or _dimension_reference.y <= 0.001 or _dimension_reference.z <= 0.001:
		return
	var target := Vector3(dimension_width, dimension_height, dimension_depth)
	if piece_type == PieceType.FOUNDATION_SQUARE or piece_type == PieceType.FOUNDATION_TRIANGLE or piece_type == PieceType.FLOOR:
		target.y = _dimension_reference.y
	if piece_type == PieceType.WALL:
		target.z = _dimension_reference.z
	scale = Vector3(target.x / _dimension_reference.x, target.y / _dimension_reference.y, target.z / _dimension_reference.z)

func _make_mesh() -> ArrayMesh:
	if piece_type == PieceType.GABLE_WALL and custom_points.size() >= 2:
		return _make_gable_wall_mesh()
	if piece_type == PieceType.GABLE_WALL_RIGHT and custom_points.size() >= 2:
		return _make_right_gable_wall_mesh()
	if (piece_type == PieceType.ROOF_GABLE or piece_type == PieceType.ROOF_SHED or piece_type == PieceType.ROOF_PYRAMID) and custom_points.size() >= 2:
		return _make_roof_mesh()
	if piece_type == PieceType.STAIRS and custom_points.size() >= 2:
		return _make_stair_mesh()
	if piece_type == PieceType.FENCE and custom_points.size() >= 2:
		return _make_fence_mesh()
	if custom_points.size() >= 2 and piece_type == PieceType.WALL:
		return _make_custom_wall_mesh()
	if custom_points.size() >= 3 and piece_type == PieceType.FLOOR:
		return _make_custom_floor_mesh()
	if custom_points.size() >= 3 and (piece_type == PieceType.FOUNDATION_SQUARE or piece_type == PieceType.FOUNDATION_TRIANGLE):
		return _make_custom_foundation_mesh()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var s := unit_size
	var polygon: Array[Vector2]
	match piece_type:
		PieceType.FOUNDATION_TRIANGLE:
			polygon = [Vector2(-s * 0.5, -s * 0.5), Vector2(s * 0.5, -s * 0.5), Vector2(-s * 0.5, s * 0.5)]
		_:
			polygon = [Vector2(-s * 0.5, -s * 0.5), Vector2(s * 0.5, -s * 0.5), Vector2(s * 0.5, s * 0.5), Vector2(-s * 0.5, s * 0.5)]
	var y0 := -thickness * 0.5 if centered_origin else 0.0
	var y1 := thickness * 0.5 if centered_origin else thickness
	if piece_type == PieceType.WALL:
		polygon = [Vector2(-s * 0.5, -thickness * 0.5), Vector2(s * 0.5, -thickness * 0.5), Vector2(s * 0.5, thickness * 0.5), Vector2(-s * 0.5, thickness * 0.5)]
		y0 = -s * 0.5 if centered_origin else 0.0
		y1 = s * 0.5 if centered_origin else s
	if piece_type == PieceType.FOUNDATION_SQUARE or piece_type == PieceType.FOUNDATION_TRIANGLE:
		var hatch_mesh := _make_hatch_surface_mesh(polygon, y1, y0)
		if hatch_mesh != null:
			return hatch_mesh
	for i in range(1, polygon.size() - 1):
		_add_tri(vertices, normals, Vector3(polygon[0].x, y1, polygon[0].y), Vector3(polygon[i + 1].x, y1, polygon[i + 1].y), Vector3(polygon[i].x, y1, polygon[i].y))
		_add_tri(vertices, normals, Vector3(polygon[0].x, y0, polygon[0].y), Vector3(polygon[i].x, y0, polygon[i].y), Vector3(polygon[i + 1].x, y0, polygon[i + 1].y))
	for i in range(polygon.size()):
		var j := (i + 1) % polygon.size()
		var a := polygon[i]
		var b := polygon[j]
		_add_tri(vertices, normals, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y))
		_add_tri(vertices, normals, Vector3(a.x, y0, a.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _make_gable_wall_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var base_points := _get_centered_gable_base() if center_align else PackedVector3Array([custom_points[0], custom_points[1]])
	var a: Vector3 = base_points[0]
	var b: Vector3 = base_points[1]
	var direction := (b - a).normalized()
	var side := Vector3(-direction.z, 0.0, direction.x).normalized() * thickness * 0.5
	var peak := (a + b) * 0.5 + Vector3.UP * rise
	var front_a := a + side
	var front_b := b + side
	var front_peak := peak + side
	var back_a := a - side
	var back_b := b - side
	var back_peak := peak - side
	_add_tri(vertices, normals, front_a, front_b, front_peak)
	_add_tri(vertices, normals, back_b, back_a, back_peak)
	_add_quad(vertices, normals, front_a, back_a, back_b, front_b)
	_add_quad(vertices, normals, front_b, back_b, back_peak, front_peak)
	_add_quad(vertices, normals, front_peak, back_peak, back_a, front_a)
	return _array_mesh(vertices, normals)

func _make_right_gable_wall_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var base_points := _get_centered_gable_base() if center_align else PackedVector3Array([custom_points[0], custom_points[1]])
	var a: Vector3 = base_points[0]
	var b: Vector3 = base_points[1]
	var direction := (b - a).normalized()
	var side := Vector3(-direction.z, 0.0, direction.x).normalized() * thickness * 0.5
	var peak := b + Vector3.UP * rise
	var front_a := a + side
	var front_b := b + side
	var front_peak := peak + side
	var back_a := a - side
	var back_b := b - side
	var back_peak := peak - side
	_add_tri(vertices, normals, front_a, front_b, front_peak)
	_add_tri(vertices, normals, back_peak, back_b, back_a)
	_add_quad(vertices, normals, front_a, back_a, back_b, front_b)
	_add_quad(vertices, normals, front_b, back_b, back_peak, front_peak)
	_add_quad(vertices, normals, front_peak, back_peak, back_a, front_a)
	return _array_mesh(vertices, normals)

func _make_roof_mesh() -> ArrayMesh:
	if piece_type == PieceType.ROOF_SHED and custom_points.size() == 2:
		return _make_shed_roof_mesh()
	if custom_points.size() >= 4:
		return _make_oriented_roof_mesh()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var first: Vector3 = custom_points[0]
	var second: Vector3 = custom_points[1]
	var min_x := minf(first.x, second.x)
	var max_x := maxf(first.x, second.x)
	var min_z := minf(first.z, second.z)
	var max_z := maxf(first.z, second.z)
	var span_x := max_x - min_x
	var span_z := max_z - min_z
	if span_x < 0.02 or span_z < 0.02:
		return _array_mesh(vertices, normals)
	var panels: Array = []
	if piece_type == PieceType.ROOF_GABLE:
		if span_x <= span_z:
			var ridge_x := (min_x + max_x) * 0.5
			panels.append([Vector3(min_x, 0.0, min_z), Vector3(min_x, 0.0, max_z), Vector3(ridge_x, rise, max_z), Vector3(ridge_x, rise, min_z)])
			panels.append([Vector3(ridge_x, rise, min_z), Vector3(ridge_x, rise, max_z), Vector3(max_x, 0.0, max_z), Vector3(max_x, 0.0, min_z)])
		else:
			var ridge_z := (min_z + max_z) * 0.5
			panels.append([Vector3(min_x, 0.0, min_z), Vector3(max_x, 0.0, min_z), Vector3(max_x, rise, ridge_z), Vector3(min_x, rise, ridge_z)])
			panels.append([Vector3(min_x, rise, ridge_z), Vector3(max_x, rise, ridge_z), Vector3(max_x, 0.0, max_z), Vector3(min_x, 0.0, max_z)])
	else:
		if span_x <= span_z:
			var low_x := first.x
			var high_x := second.x
			panels.append([Vector3(low_x, 0.0, min_z), Vector3(low_x, 0.0, max_z), Vector3(high_x, rise, max_z), Vector3(high_x, rise, min_z)])
		else:
			var low_z := first.z
			var high_z := second.z
			panels.append([Vector3(min_x, 0.0, low_z), Vector3(max_x, 0.0, low_z), Vector3(max_x, rise, high_z), Vector3(min_x, rise, high_z)])
	for panel in panels:
		_append_solid_panel(vertices, normals, panel)
	return _array_mesh(vertices, normals)

func _make_shed_roof_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var low: Vector3 = custom_points[0]
	var high: Vector3 = custom_points[1]
	var slope := high - low
	var horizontal := Vector3(slope.x, 0.0, slope.z)
	if horizontal.length_squared() < 0.0001 or roof_width <= 0.0:
		return _array_mesh(vertices, normals)
	var across := Vector3(horizontal.z, 0.0, -horizontal.x).normalized() * roof_width * 0.5
	var panel := [low - across, low + across, high + across, high - across]
	_append_solid_panel(vertices, normals, panel)
	return _array_mesh(vertices, normals)

func _make_oriented_roof_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var p0: Vector3 = custom_points[0]
	var p1: Vector3 = custom_points[1]
	var p2: Vector3 = custom_points[2]
	var p3: Vector3 = custom_points[3]
	var edge_01 := Vector2(p1.x - p0.x, p1.z - p0.z).length()
	var edge_12 := Vector2(p2.x - p1.x, p2.z - p1.z).length()
	var panels: Array = []
	if piece_type == PieceType.ROOF_GABLE:
		if edge_01 <= edge_12:
			var ridge_01 := (p0 + p1) * 0.5 + Vector3.UP * rise
			var ridge_23 := (p2 + p3) * 0.5 + Vector3.UP * rise
			panels.append([p0, p3, ridge_23, ridge_01])
			panels.append([ridge_01, ridge_23, p2, p1])
		else:
			var ridge_12 := (p1 + p2) * 0.5 + Vector3.UP * rise
			var ridge_30 := (p3 + p0) * 0.5 + Vector3.UP * rise
			panels.append([p0, p1, ridge_12, ridge_30])
			panels.append([ridge_30, ridge_12, p2, p3])
	elif piece_type == PieceType.ROOF_PYRAMID:
		var peak := (p0 + p1 + p2 + p3) * 0.25 + Vector3.UP * rise
		panels.append([p0, p1, peak])
		panels.append([p1, p2, peak])
		panels.append([p2, p3, peak])
		panels.append([p3, p0, peak])
	else:
		# The four points define the low and high edges. Keep their centers
		# fixed when adjusting both edge widths in the Inspector.
		var base_width := Vector2(p1.x - p0.x, p1.z - p0.z).length()
		if base_width > 0.001 and roof_width > 0.0:
			var direction := Vector3(p1.x - p0.x, 0.0, p1.z - p0.z).normalized()
			var low_center := (p0 + p1) * 0.5
			var high_center := (p2 + p3) * 0.5
			var half_width := roof_width * 0.5
			panels.append([
				low_center - direction * half_width,
				low_center + direction * half_width,
				high_center + direction * half_width,
				high_center - direction * half_width,
			])
		else:
			panels.append([p0, p1, p2, p3])
	for panel in panels:
		_append_solid_panel(vertices, normals, panel)
	return _array_mesh(vertices, normals)

func _make_stair_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var start: Vector3 = custom_points[0]
	var finish: Vector3 = custom_points[1]
	var horizontal := Vector3(finish.x - start.x, 0.0, finish.z - start.z)
	var run := horizontal.length()
	var rise_amount := finish.y - start.y
	if run < 0.05 or rise_amount <= 0.05 or stair_count < 1 or stair_width <= 0.0:
		return _array_mesh(vertices, normals)
	var forward := horizontal / run
	var width_axis := Vector3(-forward.z, 0.0, forward.x) * stair_width * 0.5
	var profile := PackedVector2Array([Vector2(0.0, 0.0), Vector2(run, 0.0), Vector2(run, rise_amount)])
	for step_index in range(stair_count - 1, -1, -1):
		var tread_start := run * float(step_index) / stair_count
		var tread_end := run * float(step_index + 1) / stair_count
		var tread_height := rise_amount * float(step_index + 1) / stair_count
		profile.append(Vector2(tread_start, tread_height))
		if step_index > 0:
			profile.append(Vector2(tread_start, rise_amount * float(step_index) / stair_count))
	var triangulation := Geometry2D.triangulate_polygon(profile)
	for side_sign in [-1.0, 1.0]:
		for triangle_index in range(0, triangulation.size(), 3):
			var a := profile[triangulation[triangle_index]]
			var b := profile[triangulation[triangle_index + 1]]
			var c := profile[triangulation[triangle_index + 2]]
			var point_a: Vector3 = start + forward * a.x + Vector3.UP * a.y + width_axis * side_sign
			var point_b: Vector3 = start + forward * b.x + Vector3.UP * b.y + width_axis * side_sign
			var point_c: Vector3 = start + forward * c.x + Vector3.UP * c.y + width_axis * side_sign
			if side_sign > 0.0:
				_add_tri(vertices, normals, point_a, point_b, point_c)
			else:
				_add_tri(vertices, normals, point_c, point_b, point_a)
	for profile_index in range(profile.size()):
		var next_index := (profile_index + 1) % profile.size()
		var a := profile[profile_index]
		var b := profile[next_index]
		var point_a_left := start + forward * a.x + Vector3.UP * a.y - width_axis
		var point_b_left := start + forward * b.x + Vector3.UP * b.y - width_axis
		var point_b_right := start + forward * b.x + Vector3.UP * b.y + width_axis
		var point_a_right := start + forward * a.x + Vector3.UP * a.y + width_axis
		_add_quad(vertices, normals, point_a_left, point_b_left, point_b_right, point_a_right)
	return _array_mesh(vertices, normals)

func _make_fence_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var start: Vector3 = custom_points[0]
	var finish: Vector3 = custom_points[1]
	var path := finish - start
	var path_length := path.length()
	if path_length < 0.05 or fence_height <= 0.0:
		return _array_mesh(vertices, normals)
	var path_axis := path / path_length
	var post_count := fence_divisions + 2
	var post_positions: Array[Vector3] = []
	for post_index in range(post_count):
		var base_position := start.lerp(finish, float(post_index) / float(post_count - 1))
		post_positions.append(base_position)
		var side_axis := path_axis.cross(Vector3.UP).normalized()
		if side_axis.length_squared() < 0.001:
			side_axis = Vector3.FORWARD
		_append_oriented_box(vertices, normals, base_position + Vector3.UP * fence_height * 0.5, path_axis, Vector3.UP, side_axis, Vector3(thickness, fence_height, thickness))
	for section_index in range(post_positions.size() - 1):
		var section_start := post_positions[section_index]
		var section_end := post_positions[section_index + 1]
		var section_axis := (section_end - section_start).normalized()
		var rail_up := Vector3.UP - section_axis * section_axis.dot(Vector3.UP)
		if rail_up.length_squared() < 0.001:
			rail_up = Vector3.FORWARD - section_axis * section_axis.dot(Vector3.FORWARD)
		rail_up = rail_up.normalized()
		var rail_side := section_axis.cross(rail_up).normalized()
		var section_length := section_start.distance_to(section_end)
		for height_ratio in [0.28, 0.78]:
			var rail_center: Vector3 = (section_start + section_end) * 0.5 + Vector3.UP * fence_height * height_ratio
			_append_oriented_box(vertices, normals, rail_center, section_axis, rail_up, rail_side, Vector3(section_length, thickness, thickness))
	return _array_mesh(vertices, normals)

func _append_oriented_box(vertices: PackedVector3Array, normals: PackedVector3Array, center: Vector3, axis_x: Vector3, axis_y: Vector3, axis_z: Vector3, dimensions: Vector3) -> void:
	var x := axis_x.normalized() * dimensions.x * 0.5
	var y := axis_y.normalized() * dimensions.y * 0.5
	var z := axis_z.normalized() * dimensions.z * 0.5
	var nnn := center - x - y - z
	var pnn := center + x - y - z
	var ppn := center + x + y - z
	var npn := center - x + y - z
	var nnp := center - x - y + z
	var pnp := center + x - y + z
	var ppp := center + x + y + z
	var npp := center - x + y + z
	_add_quad(vertices, normals, nnp, pnp, ppp, npp)
	_add_quad(vertices, normals, pnn, nnn, npn, ppn)
	_add_quad(vertices, normals, npp, ppp, ppn, npn)
	_add_quad(vertices, normals, nnn, pnn, pnp, nnp)
	_add_quad(vertices, normals, nnn, nnp, npp, npn)
	_add_quad(vertices, normals, pnp, pnn, ppn, ppp)

func _get_centered_gable_base() -> PackedVector3Array:
	var selected_a := to_global(custom_points[0])
	var selected_b := to_global(custom_points[1])
	var search_root: Node = get_parent()
	while search_root != null and not search_root is ModularBuilderPieceGeometry:
		search_root = search_root.get_parent()
	if search_root == null:
		return PackedVector3Array([custom_points[0], custom_points[1]])
	var walls: Array[ModularBuilderPieceGeometry] = []
	_collect_centering_walls(search_root, walls)
	var centered_a := selected_a
	var centered_b := selected_b
	var nearest_a := INF
	var nearest_b := INF
	for wall in walls:
		if wall.custom_points.size() < 2:
			continue
		var wall_a := wall.to_global(wall.custom_points[0] + Vector3.UP * wall.unit_size)
		var wall_b := wall.to_global(wall.custom_points[1] + Vector3.UP * wall.unit_size)
		var tolerance: float = wall.thickness + 0.04
		for endpoint in [wall_a, wall_b]:
			var distance_a := selected_a.distance_to(endpoint)
			if distance_a < nearest_a and distance_a <= tolerance:
				nearest_a = distance_a
				centered_a = endpoint
			var distance_b := selected_b.distance_to(endpoint)
			if distance_b < nearest_b and distance_b <= tolerance:
				nearest_b = distance_b
				centered_b = endpoint
	if nearest_a < INF and nearest_b < INF and centered_a.distance_to(centered_b) >= 0.02:
		return PackedVector3Array([to_local(centered_a), to_local(centered_b)])
	return PackedVector3Array([custom_points[0], custom_points[1]])

func _collect_centering_walls(node: Node, walls: Array[ModularBuilderPieceGeometry]) -> void:
	if node is ModularBuilderPieceGeometry and node.piece_type == PieceType.WALL:
		walls.append(node)
	for child in node.get_children():
		_collect_centering_walls(child, walls)

func _append_solid_panel(vertices: PackedVector3Array, normals: PackedVector3Array, panel: Array) -> void:
	if panel.size() < 3:
		return
	var p0: Vector3 = panel[0]
	var p1: Vector3 = panel[1]
	var p2: Vector3 = panel[2]
	var normal: Vector3 = (p1 - p0).cross(p2 - p0).normalized()
	if normal.is_zero_approx():
		return
	var half_depth: Vector3 = normal * thickness * 0.5
	var front: Array[Vector3] = []
	var back: Array[Vector3] = []
	for point in panel:
		front.append(point + half_depth)
		back.append(point - half_depth)
	for i in range(1, panel.size() - 1):
		_add_tri(vertices, normals, front[0], front[i], front[i + 1])
		_add_tri(vertices, normals, back[i + 1], back[i], back[0])
	for i in range(panel.size()):
		var next := (i + 1) % panel.size()
		_add_quad(vertices, normals, front[i], back[i], back[next], front[next])

func _make_custom_wall_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var wall_points: PackedVector3Array = _get_centered_wall_points() if center_align else custom_points
	var a: Vector3 = wall_points[0]
	var b: Vector3 = wall_points[1]
	var direction := (b - a).normalized()
	var length := a.distance_to(b)
	var side := Vector3(-direction.z, 0.0, direction.x).normalized() * thickness * 0.5
	var height := Vector3.UP * unit_size
	var openings: Array[PackedVector2Array] = []
	for child in get_children():
		if _is_detail_node(child) and int(child.get("detail_type")) != DETAIL_TYPE_HATCH and int(child.get("detail_type")) != DETAIL_TYPE_PILLAR:
			var detail := child as Node3D
			var center := Vector2((detail.position - a).dot(direction), detail.position.y - a.y)
			var axis_x := Vector2(detail.transform.basis.x.dot(direction), detail.transform.basis.x.y).normalized()
			var axis_y := Vector2(detail.transform.basis.y.dot(direction), detail.transform.basis.y.y).normalized()
			var opening := PackedVector2Array([
				center - axis_x * float(detail.get("width")) * 0.5 - axis_y * float(detail.get("height")) * 0.5,
				center + axis_x * float(detail.get("width")) * 0.5 - axis_y * float(detail.get("height")) * 0.5,
				center + axis_x * float(detail.get("width")) * 0.5 + axis_y * float(detail.get("height")) * 0.5,
				center - axis_x * float(detail.get("width")) * 0.5 + axis_y * float(detail.get("height")) * 0.5
			])
			var wall_rect := PackedVector2Array([Vector2(0.0, 0.0), Vector2(length, 0.0), Vector2(length, unit_size), Vector2(0.0, unit_size)])
			for clipped_opening in Geometry2D.intersect_polygons(opening, wall_rect):
				if clipped_opening.size() >= 3:
					openings.append(clipped_opening)
	var xs: Array[float] = [0.0, length]
	var ys: Array[float] = [0.0, unit_size]
	for opening in openings:
		for point in opening:
			xs.append(clampf(point.x, 0.0, length))
			ys.append(clampf(point.y, 0.0, unit_size))
	xs.sort()
	ys.sort()
	for xi in range(xs.size() - 1):
		for yi in range(ys.size() - 1):
			var u0: float = xs[xi]
			var u1: float = xs[xi + 1]
			var v0: float = ys[yi]
			var v1: float = ys[yi + 1]
			var mid := Vector2((u0 + u1) * 0.5, (v0 + v1) * 0.5)
			var cell := PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])
			var remaining: Array[PackedVector2Array] = [cell]
			for opening in openings:
				var next_remaining: Array[PackedVector2Array] = []
				for polygon in remaining:
					for clipped in Geometry2D.clip_polygons(polygon, opening):
						if clipped.size() >= 3:
							next_remaining.append(clipped)
				remaining = next_remaining
			for polygon in remaining:
				var indices := Geometry2D.triangulate_polygon(polygon)
				for ti in range(0, indices.size(), 3):
					var p0: Vector2 = polygon[indices[ti]]
					var p1: Vector2 = polygon[indices[ti + 1]]
					var p2: Vector2 = polygon[indices[ti + 2]]
					var f0 := a + direction * p0.x + Vector3.UP * p0.y
					var f1 := a + direction * p1.x + Vector3.UP * p1.y
					var f2 := a + direction * p2.x + Vector3.UP * p2.y
					_add_tri(vertices, normals, f0 + side, f1 + side, f2 + side)
					_add_tri(vertices, normals, f2 - side, f1 - side, f0 - side)
	# Close the wall body at its ends, top, and base.
	_add_quad(vertices, normals, a - side, a + side, a + side + height, a - side + height)
	_add_quad(vertices, normals, b + side, b - side, b - side + height, b + side + height)
	_add_quad(vertices, normals, a + side + height, b + side + height, b - side + height, a - side + height)
	_add_quad(vertices, normals, a - side, b - side, b + side, a + side)
	for opening in openings:
		for edge_index in range(opening.size()):
			var p0 := opening[edge_index]
			var p1 := opening[(edge_index + 1) % opening.size()]
			var a0 := a + direction * p0.x + Vector3.UP * p0.y
			var a1 := a + direction * p1.x + Vector3.UP * p1.y
			_add_quad(vertices, normals, a0 + side, a0 - side, a1 - side, a1 + side)
	return _array_mesh(vertices, normals)

func _get_centered_wall_points() -> PackedVector3Array:
	if custom_points.size() < 2:
		return custom_points
	var selected_a := to_global(custom_points[0])
	var selected_b := to_global(custom_points[1])
	var search_root: Node = get_parent()
	while search_root != null and not search_root is ModularBuilderPieceGeometry:
		search_root = search_root.get_parent()
	if search_root == null:
		return custom_points
	var walls: Array[ModularBuilderPieceGeometry] = []
	_collect_centering_walls(search_root, walls)
	var centered_a := selected_a
	var centered_b := selected_b
	var nearest_a := INF
	var nearest_b := INF
	for wall in walls:
		if wall == self or wall.custom_points.size() < 2:
			continue
		var direction := (wall.custom_points[1] - wall.custom_points[0]).normalized()
		var side := Vector3(-direction.z, 0.0, direction.x).normalized() * wall.thickness * 0.5
		for endpoint in wall.custom_points:
			var center := wall.to_global(endpoint + Vector3.UP * wall.unit_size)
			for surface_corner in [center + side, center - side]:
				var distance_a := selected_a.distance_to(surface_corner)
				if distance_a < nearest_a and distance_a <= wall.thickness + 0.04:
					nearest_a = distance_a
					centered_a = center
				var distance_b := selected_b.distance_to(surface_corner)
				if distance_b < nearest_b and distance_b <= wall.thickness + 0.04:
					nearest_b = distance_b
					centered_b = center
	if nearest_a < INF and nearest_b < INF and centered_a.distance_to(centered_b) >= 0.02:
		return PackedVector3Array([to_local(centered_a), to_local(centered_b)])
	return custom_points

func _make_custom_floor_mesh() -> ArrayMesh:
	var polygon: Array[Vector2] = []
	for point in custom_points:
		polygon.append(Vector2(point.x, point.z))
	var hatch_mesh := _make_hatch_surface_mesh(polygon, custom_points[0].y, custom_points[0].y - thickness)
	if hatch_mesh != null:
		return hatch_mesh
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var points := custom_points
	var bottom: Array[Vector3] = []
	for point in points:
		bottom.append(point - Vector3.UP * thickness)
	for i in range(1, points.size() - 1):
		_add_tri(vertices, normals, points[0], points[i + 1], points[i])
		_add_tri(vertices, normals, bottom[0], bottom[i], bottom[i + 1])
	for i in range(points.size()):
		var j := (i + 1) % points.size()
		_add_quad(vertices, normals, bottom[i], bottom[j], points[j], points[i])
	return _array_mesh(vertices, normals)

func _make_hatch_surface_mesh(polygon: Array[Vector2], top_y: float, bottom_y: float) -> ArrayMesh:
	var openings: Array[PackedVector2Array] = []
	for child in get_children():
		if _is_detail_node(child) and int(child.get("detail_type")) == DETAIL_TYPE_HATCH:
			var detail := child as Node3D
			var center := Vector2(detail.position.x, detail.position.z)
			var axis_x := Vector2(detail.transform.basis.x.x, detail.transform.basis.x.z).normalized()
			var axis_y := Vector2(detail.transform.basis.z.x, detail.transform.basis.z.z).normalized()
			var opening := PackedVector2Array([
				center - axis_x * float(detail.get("width")) * 0.5 - axis_y * float(detail.get("height")) * 0.5,
				center + axis_x * float(detail.get("width")) * 0.5 - axis_y * float(detail.get("height")) * 0.5,
				center + axis_x * float(detail.get("width")) * 0.5 + axis_y * float(detail.get("height")) * 0.5,
				center - axis_x * float(detail.get("width")) * 0.5 + axis_y * float(detail.get("height")) * 0.5
			])
			openings.append(opening)
	if openings.is_empty() or polygon.size() < 3:
		return null
	var min_x := polygon[0].x
	var max_x := polygon[0].x
	var min_z := polygon[0].y
	var max_z := polygon[0].y
	var xs: Array[float] = []
	var zs: Array[float] = []
	for point in polygon:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_z = minf(min_z, point.y)
		max_z = maxf(max_z, point.y)
		xs.append(point.x)
		zs.append(point.y)
	for opening in openings:
		for point in opening:
			xs.append(clampf(point.x, min_x, max_x))
			zs.append(clampf(point.y, min_z, max_z))
	xs.sort()
	zs.sort()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var source_polygon := PackedVector2Array()
	for point in polygon:
		source_polygon.append(point)
	for xi in range(xs.size() - 1):
		for zi in range(zs.size() - 1):
			var x0: float = xs[xi]
			var x1: float = xs[xi + 1]
			var z0: float = zs[zi]
			var z1: float = zs[zi + 1]
			if x1 - x0 < 0.0001 or z1 - z0 < 0.0001:
				continue
			var cell := PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)])
			var remaining: Array[PackedVector2Array] = []
			for clipped_surface in Geometry2D.intersect_polygons(source_polygon, cell):
				remaining.append(clipped_surface)
			for opening in openings:
				var next_remaining: Array[PackedVector2Array] = []
				for surface_polygon in remaining:
					for clipped_surface in Geometry2D.clip_polygons(surface_polygon, opening):
						if clipped_surface.size() >= 3:
							next_remaining.append(clipped_surface)
				remaining = next_remaining
			for clipped_surface in remaining:
				var triangulated := Geometry2D.triangulate_polygon(clipped_surface)
				for ti in range(0, triangulated.size(), 3):
					var a: Vector2 = clipped_surface[triangulated[ti]]
					var b: Vector2 = clipped_surface[triangulated[ti + 1]]
					var c: Vector2 = clipped_surface[triangulated[ti + 2]]
					_add_tri(vertices, normals, Vector3(a.x, top_y, a.y), Vector3(c.x, top_y, c.y), Vector3(b.x, top_y, b.y))
					_add_tri(vertices, normals, Vector3(a.x, bottom_y, a.y), Vector3(b.x, bottom_y, b.y), Vector3(c.x, bottom_y, c.y))
	for i in range(polygon.size()):
		var j := (i + 1) % polygon.size()
		var a := polygon[i]
		var b := polygon[j]
		_add_quad(vertices, normals, Vector3(a.x, bottom_y, a.y), Vector3(b.x, bottom_y, b.y), Vector3(b.x, top_y, b.y), Vector3(a.x, top_y, a.y))
	for opening in openings:
		var visible_edges := Geometry2D.intersect_polygons(opening, source_polygon)
		for visible_opening in visible_edges:
			for edge_index in range(visible_opening.size()):
				var p0 := visible_opening[edge_index]
				var p1 := visible_opening[(edge_index + 1) % visible_opening.size()]
				_add_quad(vertices, normals, Vector3(p0.x, bottom_y, p0.y), Vector3(p0.x, top_y, p0.y), Vector3(p1.x, top_y, p1.y), Vector3(p1.x, bottom_y, p1.y))
	return _array_mesh(vertices, normals)

func _is_detail_node(node: Node) -> bool:
	if not node is Node3D or node.get_script() == null:
		return false
	return node.get_script().resource_path == DETAIL_SCRIPT_PATH

func _make_custom_foundation_mesh() -> ArrayMesh:
	var polygon: Array[Vector2] = []
	for point in custom_points:
		polygon.append(Vector2(point.x, point.z))
	var bottom_y := -thickness * 0.5 if centered_origin else 0.0
	var top_y := thickness * 0.5 if centered_origin else thickness
	var hatch_mesh := _make_hatch_surface_mesh(polygon, top_y, bottom_y)
	if hatch_mesh != null:
		return hatch_mesh
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(1, custom_points.size() - 1):
		var a := custom_points[0]
		var b := custom_points[i]
		var c := custom_points[i + 1]
		_add_tri(vertices, normals, Vector3(a.x, top_y, a.z), Vector3(c.x, top_y, c.z), Vector3(b.x, top_y, b.z))
		_add_tri(vertices, normals, Vector3(a.x, bottom_y, a.z), Vector3(b.x, bottom_y, b.z), Vector3(c.x, bottom_y, c.z))
	for i in range(custom_points.size()):
		var j := (i + 1) % custom_points.size()
		var a := custom_points[i]
		var b := custom_points[j]
		_add_quad(vertices, normals, Vector3(a.x, bottom_y, a.z), Vector3(b.x, bottom_y, b.z), Vector3(b.x, top_y, b.z), Vector3(a.x, top_y, a.z))
	return _array_mesh(vertices, normals)

func _add_quad(v: PackedVector3Array, n: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_add_tri(v, n, a, b, c)
	_add_tri(v, n, a, c, d)

func _array_mesh(v: PackedVector3Array, n: PackedVector3Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _add_tri(v: PackedVector3Array, n: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	v.append(a)
	v.append(b)
	v.append(c)
	n.append(normal)
	n.append(normal)
	n.append(normal)
	# Also generate reversed faces to show both sides.
	# This keeps floors and foundations visible from below with any material.
	v.append(c)
	v.append(b)
	v.append(a)
	n.append(-normal)
	n.append(-normal)
	n.append(-normal)
