extends Node3D

## Verification harness: builds Gloamwick and reports the terrain state.

func _ready() -> void:
	var g = load("res://world/gloamwick.gd").new()
	g.name = "Gloamwick"
	add_child(g)
	g.build()
	print("GTEST anchors=", g.get_anchors().size())
	var t = g.get_node_or_null("Terrain/Terrain3D")
	print("GTEST terrain3d node=", t)
	if t != null:
		print("GTEST height@town(0,-16)=", t.data.get_height(Vector3(0, 0, -16)))
		print("GTEST height@tower(0,-116)=", t.data.get_height(Vector3(0, 0, -116)))
		print("GTEST height@hill(60,-60)=", t.data.get_height(Vector3(60, 0, -60)))
	var cam := Camera3D.new()
	cam.position = Vector3(0, 12, 40)
	cam.rotation_degrees = Vector3(-18, 0, 0)
	cam.current = true
	add_child(cam)
	print("GTEST done")