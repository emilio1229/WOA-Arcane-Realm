@tool
class_name ModularBuilderPiece
extends "res://addons/modular_builder_en/modular_piece_geometry.gd"

func _ready() -> void:
	_rebuild()

func _validate_property(property: Dictionary) -> void:
	if property.name == &"symmetric_dimensions" and piece_type == PieceType.BUILDING:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == &"dimension_height" and (piece_type == PieceType.FOUNDATION_SQUARE or piece_type == PieceType.FOUNDATION_TRIANGLE or piece_type == PieceType.FLOOR):
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == &"dimension_depth" and piece_type == PieceType.WALL:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == &"dimension_width" or property.name == &"dimension_height" or property.name == &"dimension_depth":
		if symmetric_dimensions:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == &"rise" and piece_type != PieceType.GABLE_WALL and piece_type != PieceType.GABLE_WALL_RIGHT and piece_type != PieceType.ROOF_GABLE and piece_type != PieceType.ROOF_PYRAMID:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == &"roof_width" and piece_type != PieceType.ROOF_SHED:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == &"stair_count" and piece_type != PieceType.STAIRS:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == &"stair_width" and piece_type != PieceType.STAIRS:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == &"fence_divisions" and piece_type != PieceType.FENCE:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == &"fence_height" and piece_type != PieceType.FENCE:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == &"center_align" and piece_type != PieceType.GABLE_WALL and piece_type != PieceType.GABLE_WALL_RIGHT and piece_type != PieceType.WALL:
		property.usage = PROPERTY_USAGE_NO_EDITOR

func _rebuild() -> void:
	if not is_inside_tree():
		return
	var old_collision := get_node_or_null("Collision")
	if old_collision != null:
		remove_child(old_collision)
		old_collision.queue_free()
	var mesh_instance := get_node_or_null("Geometry") as MeshInstance3D
	if piece_type == PieceType.BUILDING:
		if mesh_instance != null:
			remove_child(mesh_instance)
			mesh_instance.queue_free()
		return
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Geometry"
		add_child(mesh_instance)
		_set_scene_owner(mesh_instance)
	mesh_instance.mesh = _make_mesh()
	mesh_instance.material_override = surface_material
	if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		_dimension_reference = mesh_instance.mesh.get_aabb().size
		_apply_dimension_scale()

func _set_scene_owner(node: Node) -> void:
	if Engine.is_editor_hint():
		var scene_root := get_tree().edited_scene_root
		if scene_root:
			node.owner = scene_root
