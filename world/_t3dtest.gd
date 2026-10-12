extends Node3D

## Standalone Terrain3D smoke test (used for verification only).

func _ready() -> void:
	print("T3DTEST start")
	var t = ClassDB.instantiate("Terrain3D")
	if t == null:
		print("T3DTEST FAIL: no Terrain3D class")
		return
	t.name = "Terrain3D"
	add_child(t)
	print("T3DTEST node added")
	t.region_size = 256
	print("T3DTEST region_size=", t.region_size)
	if ResourceLoader.exists("res://demo/data/assets.tres"):
		t.assets = load("res://demo/data/assets.tres")
		print("T3DTEST assets assigned: ", t.assets)
	var img := Image.create_empty(256, 256, false, Image.FORMAT_RF)
	for x in 256:
		for y in 256:
			img.set_pixel(x, y, Color(sin(x * 0.05) * 3.0, 0.0, 0.0, 1.0))
	t.data.import_images([img, null, null], Vector3(0, 0, 0), 0.0, 1.0)
	print("T3DTEST height@(128,0,128)=", t.data.get_height(Vector3(128, 0, 128)))
	print("T3DTEST height@(10,0,10)=", t.data.get_height(Vector3(10, 0, 10)))
	t.collision.mode = Terrain3DCollision.DYNAMIC_GAME
	print("T3DTEST collision mode OK")
	var cam := Camera3D.new()
	cam.position = Vector3(128, 80, 220)
	cam.rotation_degrees = Vector3(-35, 0, 0)
	cam.current = true
	add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	add_child(sun)
	print("T3DTEST done")