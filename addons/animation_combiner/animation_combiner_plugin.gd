@tool
extends EditorPlugin

var dock: Control


func _enter_tree() -> void:
	# Create and add the dock — bypass resource cache so edits to the TSCN are picked up immediately
	var scene: PackedScene = ResourceLoader.load(
		"res://addons/animation_combiner/animation_combiner_dock.tscn",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	dock = scene.instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)


func _exit_tree() -> void:
	# Remove the dock when plugin is disabled
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
