class_name Gloamwick
extends Node3D

## Gloamwick — the first complete, playable 3D world of WOA: Arcane Realm.
##
## This node builds the entire settlement environment (terrain, roads, market,
## modular buildings, props, nature, landmarks and lighting) and reports the
## gameplay anchor points that main.gd needs to place Mathias, the Sigils and
## the encounter. It is pure environment: it builds no quest logic.
##
## Only OBJ meshes are used, because the project's FBX/GLB/glTF assets are Git
## LFS pointer stubs (their binaries were never pulled) and cannot be imported.
## OBJ materials are rebuilt from res://Textures via GloamwickMaterials.

const Materials := preload("res://world/gloamwick_materials.gd")

const KIT := "res://OBJ/"                # modular medieval village kit
const PROPS := "res://Exports/OBJ/"      # props / furniture / cargo pack
const MODELS := "res://Assets/Models/"   # hand-authored landmarks

# Wall module is 2 m wide and 3.12 m tall on the kit grid.
const WALL_W := 2.0
const WALL_H := 3.12

var _mesh_cache: Dictionary = {}
var _batches: Dictionary = {}
var _anchors: Dictionary = {}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func get_anchors() -> Dictionary:
	return _anchors

func build() -> void:
	_anchors = {
		"player_spawn": Vector3(0.0, 0.0, 23.0),
		"well": Vector3(0.0, 1.15, -16.5),
		"mathias": Vector3(0.0, 0.0, -35.0),
		"enemies": [
			Vector3(-3.2, 0.0, -40.5),
			Vector3(0.0, 0.0, -40.5),
			Vector3(3.2, 0.0, -40.5),
		],
		"sigils": [
			Vector3(-8.0, 1.1, -48.0),
			Vector3(8.0, 1.1, -48.0),
			Vector3(0.0, 1.1, -54.0),
		],
		"gate_sigil": Vector3(0.0, 2.4, -61.45),
		"archive_wisp": Vector3(10.5, 2.0, -45.0),
		"tower": Vector3(0.0, 0.0, -116.0),
	}

	var terrain := _group("Terrain")
	_build_terrain(terrain)
	var roads := _group("Roads")
	_build_roads(roads)
	var landmarks := _group("Landmarks")
	_build_landmarks(landmarks)
	_flush(landmarks)
	var buildings := _group("Buildings")
	_build_buildings(buildings)
	_flush(buildings)
	var market := _group("Market")
	_build_market(market)
	_flush(market)
	var props := _group("Props")
	_build_props(props)
	_flush(props)
	var nature := _group("Nature")
	_build_nature(nature)
	# Nature never casts shadows: re-drawing hundreds of trees into the shadow
	# map every frame is what cost the most on the Compatibility renderer.
	_flush(nature, false)
	var lighting := _group("Lighting")
	_build_lighting(lighting)

# ---------------------------------------------------------------------------
# Terrain
# ---------------------------------------------------------------------------

func _height(x: float, z: float) -> float:
	# The settlement footprint stays essentially flat for clean traversal;
	# rolling hills and a wooded ridge rise beyond it.
	var dx: float = maxf(0.0, absf(x) - 42.0)
	var dz: float = maxf(0.0, absf(z + 20.0) - 54.0)
	var d: float = sqrt(dx * dx + dz * dz)
	var t: float = clampf(d / 55.0, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var hills: float = 6.0 * sin(x * 0.045 + 0.6) * cos(z * 0.05 - 0.3) \
		+ 2.5 * sin(x * 0.11) * sin(z * 0.09 + 1.1) \
		+ 1.2 * cos(x * 0.2 + z * 0.13)
	var outside: float = lerpf(0.0, hills + 4.0, t)
	var inside: float = 0.10 * sin(x * 0.35) * cos(z * 0.32)
	return inside + outside

func _build_terrain(parent: Node3D) -> void:
	# Prefer the Terrain3D GDExtension when it is available (Forward+/Mobile
	# renderers). Falls back to the hand-built heightfield under Compatibility.
	# Terrain3D needs a RenderingDevice renderer (Forward+/Mobile); the project
	# ships on Compatibility for the web build, where we use the hand-built
	# heightfield instead. If the project is later switched to Forward+, this
	# path activates automatically.
	if RenderingServer.get_rendering_device() != null and ClassDB.class_exists("Terrain3D") and _build_terrain3d(parent):
		return
	_build_custom_terrain(parent)

func _build_terrain3d(parent: Node3D) -> bool:
	var terrain = ClassDB.instantiate("Terrain3D")
	if terrain == null:
		return false
	terrain.name = "Terrain3D"
	parent.add_child(terrain)
	terrain.region_size = 256
	terrain.material.world_background = Terrain3DMaterial.NONE
	terrain.material.auto_shader = true
	if ResourceLoader.exists("res://demo/data/assets.tres"):
		terrain.assets = load("res://demo/data/assets.tres")
	# Build 4 regions (2x2) covering a 512 x 512 m playable area, 1 m per pixel.
	var size := 256
	var origins := [
		Vector3(0, 0, 0), Vector3(-256, 0, 0), Vector3(0, 0, -256), Vector3(-256, 0, -256),
	]
	for origin in origins:
		var img := Image.create_empty(size, size, false, Image.FORMAT_RF)
		for x in size:
			for y in size:
				img.set_pixel(x, y, Color(_height(origin.x + float(x), origin.z + float(y)), 0.0, 0.0, 1.0))
		terrain.data.import_images([img, null, null], origin, 0.0, 1.0)
	terrain.collision.mode = Terrain3DCollision.DYNAMIC_GAME
	terrain.collision_mask = 1
	return true

func _build_custom_terrain(parent: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := -140.0
	var x1 := 140.0
	var z0 := -180.0
	var z1 := 110.0
	var step := 3.0
	var nx := int((x1 - x0) / step)
	var nz := int((z1 - z0) / step)
	for i in range(nx):
		for j in range(nz):
			var xa := x0 + float(i) * step
			var xb := xa + step
			var za := z0 + float(j) * step
			var zb := za + step
			var a := Vector3(xa, _height(xa, za), za)
			var b := Vector3(xb, _height(xb, za), za)
			var c := Vector3(xb, _height(xb, zb), zb)
			var d := Vector3(xa, _height(xa, zb), zb)
			_tri(st, a, b, c)
			_tri(st, a, c, d)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "GloamwickGround"
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://Textures/Grass.png")
	mat.albedo_color = Color(0.4, 0.44, 0.4)
	mat.uv1_scale = Vector3(0.16, 0.16, 0.16)
	mat.roughness = 1.0
	mi.material_override = mat
	parent.add_child(mi)

	# Collision from the same mesh so the whole world is walkable.
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	parent.add_child(body)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for v in [a, b, c]:
		st.set_uv(Vector2(v.x * 0.16, v.z * 0.16))
		st.add_vertex(v)

# ---------------------------------------------------------------------------
# Roads, paths and clearing
# ---------------------------------------------------------------------------

func _build_roads(parent: Node3D) -> void:
	var stone := _box_material("res://Textures/T_UnevenBrick_BaseColor.png", Color(0.30, 0.28, 0.34), 0.0)
	var dirt := _box_material("res://Textures/Grass.png", Color(0.34, 0.30, 0.26), 0.0)
	_road(parent, "North Road", Vector3(0, 0.05, 4), Vector3(7.0, 0.1, 42.0), stone)
	_road(parent, "South Ward Road", Vector3(0, 0.05, -42), Vector3(6.0, 0.1, 38.0), stone)
	_road(parent, "Market Square", Vector3(0, 0.06, -14), Vector3(32.0, 0.1, 24.0), stone)
	_road(parent, "Square Inlay", Vector3(0, 0.11, -14), Vector3(12.0, 0.04, 12.0), _box_material("res://Textures/T_RoundTiles_BaseColor.png", Color(0.40, 0.36, 0.42), 0.0))
	_road(parent, "West Lane", Vector3(-19, 0.05, -14), Vector3(4.0, 0.1, 30.0), dirt)
	_road(parent, "East Lane", Vector3(19, 0.05, -14), Vector3(4.0, 0.1, 30.0), dirt)
	# Battle clearing where Mathias holds the southern ward.
	_road(parent, "Battle Clearing", Vector3(0, 0.05, -39), Vector3(24.0, 0.1, 20.0), dirt)

func _road(parent: Node3D, label: String, pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var m: StandardMaterial3D = mat.duplicate()
	m.uv1_scale = Vector3(size.x * 0.4, size.z * 0.4, 1.0)
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)

# ---------------------------------------------------------------------------
# Landmarks
# ---------------------------------------------------------------------------

func _build_landmarks(parent: Node3D) -> void:
	# North entrance gate: two flanking arches the player walks between.
	_place(parent, KIT + "Wall_Arch.obj", Vector3(-4.2, 0, 9.0), 0.0, 1.6)
	_place(parent, KIT + "Wall_Arch.obj", Vector3(4.2, 0, 9.0), 0.0, 1.6)
	# Rune well in the market centre.
	_well(parent)
	# Ward stone gate at the southern edge of the settlement.
	_box(parent, "Sanctuary Gate", Vector3(0, 3.0, -62), Vector3(11, 6, 0.9),
		_box_material("res://Textures/T_RockTrim_BaseColor.png", Color(0.55, 0.52, 0.62), 0.0), true)
	_place(parent, KIT + "Corner_ExteriorWide_Brick.obj", Vector3(-5.5, 0, -62), 0.0, 2.0)
	_place(parent, KIT + "Corner_ExteriorWide_Brick.obj", Vector3(5.5, 0, -62), 0.0, 2.0)
	# Broken stones and forgotten shrine along the old ward road.
	_place(parent, MODELS + "rune_shrine.obj", Vector3(10.5, 0, -45), -0.5, 1.0)
	_place(parent, KIT + "Rock_Medium_2.obj", Vector3(23.5, 0, -18), 0.7, 2.2)
	_place(parent, KIT + "Rock_Medium_1.obj", Vector3(-8.8, 0, -44), 0.3, 1.6)
	_place(parent, MODELS + "relic_chest.obj", Vector3(-16.0, 0, -30), 0.8, 1.0)
	# Tall rune lamps lining the ward road toward Mathias.
	for i in range(6):
		var z: float = -26.0 - float(i) * 3.4
		for side in [-1.0, 1.0]:
			var lx: float = float(side) * (5.5 if i < 3 else 7.5)
			_road_lamp(parent, Vector3(lx, 0, z))
	_build_tower(parent)

func _build_tower(parent: Node3D) -> void:
	# The vast wizard tower that the whole opening chapter points toward.
	var base_x := 0.0
	var base_z := -116.0
	var base_y := _height(base_x, base_z)
	var tower := Node3D.new()
	tower.name = "WizardTower"
	tower.position = Vector3(base_x, base_y, base_z)
	parent.add_child(tower)
	# The real wizard-tower model, scaled to a vast ~44 m landmark.
	var tower_path := "res://Assets/generated/tower_opt.res"
	if ResourceLoader.exists(tower_path):
		var tower_mesh := load(tower_path) as Mesh
		if tower_mesh != null:
			var tmi := MeshInstance3D.new()
			tmi.mesh = tower_mesh
			var ta := tower_mesh.get_aabb()
			var ts := 44.0 / maxf(ta.size.y, 0.001)
			tmi.scale = Vector3.ONE * ts
			var tc := ta.get_center()
			tmi.position = Vector3(-tc.x * ts, 0.0, -tc.z * ts)
			tower.add_child(tmi)
	# Solid collision so the tower blocks movement, and violet glow at base + crown.
	var h := 44.0
	_tower_wall(tower, Vector3(0.0, h * 0.5, 0.0), Vector3(11.0, h, 11.0))
	_omni(tower, Vector3(0.0, 6.0, 8.0), Color(0.7, 0.35, 1.0), 4.0, 70.0)
	_omni(tower, Vector3(0.0, 42.0, 0.0), Color(0.6, 0.3, 1.0), 4.0, 90.0)

func _tower_wall(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	sb.add_child(col)
	sb.position = pos
	parent.add_child(sb)

func _well(parent: Node3D) -> void:
	var stone := _box_material("res://Textures/T_RockTrim_BaseColor.png", Color(0.55, 0.52, 0.62), 0.0)
	_box(parent, "Rune Well Foundation", Vector3(0, 0.3, -16.5), Vector3(3.6, 0.6, 3.6), stone, true)
	var inner := _box(parent, "Rune Well Pool", Vector3(0, 0.62, -16.5), Vector3(2.2, 0.14, 2.2),
		_box_material("res://Textures/T_WindowGradient.png", Color(0.3, 0.7, 1.0), 0.0), false)
	var water_mat: StandardMaterial3D = inner.get_child(0).material_override
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.2, 0.6, 0.95)
	water_mat.emission_energy_multiplier = 0.9
	# Four corner posts.
	for sx in [-1.5, 1.5]:
		for sz in [-1.5, 1.5]:
			_place(parent, KIT + "Prop_Support.obj", Vector3(sx, 0.6, -16.5 + sz), 0.0, 1.0)

func _road_lamp(parent: Node3D, pos: Vector3) -> void:
	var post := _box(parent, "Lamp Post", pos + Vector3(0, 1.7, 0), Vector3(0.16, 3.4, 0.16),
		_box_material("res://Textures/T_WoodTrim_BaseColor.png", Color(0.3, 0.26, 0.34), 0.0), false)
	post.get_child(0).material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Emissive lantern cage (hung inverted).
	_place(parent, PROPS + "Lantern_Wall.obj", pos + Vector3(0, 3.15, 0), 0.0, 0.9, PI)

# ---------------------------------------------------------------------------
# Buildings (modular medieval kit)
# ---------------------------------------------------------------------------

func _build_buildings(parent: Node3D) -> void:
	# The Hollow Lantern inn anchors the east side of the market.
	_house(parent, Vector3(21, 0, -13), 8, -PI * 0.5, 2)
	_label3d(parent, "The Hollow Lantern", Vector3(17.0, 4.2, -13), -PI * 0.5)
	# Ring of homes around the square.
	var homes := [
		[Vector3(-21, 0, 3), 6, PI * 0.5],
		[Vector3(-21, 0, -13), 6, PI * 0.5],
		[Vector3(-21, 0, -29), 6, PI * 0.5],
		[Vector3(21, 0, 3), 6, -PI * 0.5],
		[Vector3(21, 0, -29), 6, -PI * 0.5],
		[Vector3(-21, 0, 20), 6, PI * 0.5],
	]
	for i in range(homes.size()):
		var h = homes[i]
		_house(parent, h[0], h[1], h[2], 1)

func _house(parent: Node3D, center: Vector3, size: int, yaw: float, storeys: int) -> void:
	var half := float(size) / 2.0
	var n := int(float(size) / 2.0)
	var body := Node3D.new()
	body.name = "House_%d" % int(absf(center.x) + absf(center.z))
	body.position = center
	body.rotation.y = yaw
	parent.add_child(body)

	# Solid walls all the way around, storey by storey.
	for s in range(storeys):
		var y := float(s) * WALL_H
		for k in range(n):
			var off := -half + 1.0 + float(k) * WALL_W
			_place(body, KIT + "Wall_Plaster_Straight.obj", Vector3(off, y, half), 0.0)
			_place(body, KIT + "Wall_Plaster_Straight.obj", Vector3(off, y, -half), PI)
			_place(body, KIT + "Wall_Plaster_Straight.obj", Vector3(-half, y, off), -PI * 0.5)
			_place(body, KIT + "Wall_Plaster_Straight.obj", Vector3(half, y, off), PI * 0.5)

	# Door on the +Z (front) face.
	_place(body, KIT + "Door_1_Flat.obj", Vector3(0.0, 0.0, half + 0.05), 0.0)
	# Windows: ground floor sides and front, upper floor for taller homes.
	for side in [-half, half]:
		_place(body, KIT + "Window_Wide_Flat1.obj", Vector3(side, 1.6, -1.0), PI * 0.5 if side > 0 else -PI * 0.5)
		_place(body, KIT + "Window_Wide_Flat1.obj", Vector3(side, 1.6, 1.2), PI * 0.5 if side > 0 else -PI * 0.5)
	_place(body, KIT + "Window_Wide_Flat1.obj", Vector3(half - 1.2, 0.0, half + 0.05), 0.0)
	if storeys >= 2:
		_place(body, KIT + "Window_Thin_Round1.obj", Vector3(-1.0, WALL_H, half + 0.05), 0.0)
		_place(body, KIT + "Window_Thin_Round1.obj", Vector3(1.0, WALL_H, half + 0.05), 0.0)

	# A timber frame band between floors and at the eaves.
	for s in range(1, storeys):
		_frame_ring(body, float(s) * WALL_H - 0.12, size)

	# Roof sized exactly to the square footprint (kit resolves square roofs cleanly).
	_place(body, KIT + ("Roof_RoundTiles_%dx%d.obj" % [size, size]), Vector3(0, float(storeys) * WALL_H - 0.25, 0), 0.0)
	# Chimney.
	_place(body, KIT + "Prop_Chimney.obj", Vector3(half - 0.9, float(storeys) * WALL_H + 0.4, half - 0.9), 0.0, 1.0)
	# Wall lantern beside the door.
	_place(body, PROPS + "Lantern_Wall.obj", Vector3(half - 0.7, 2.15, half + 0.18), 0.0, 0.8)

	# Collision: one solid box for the whole building footprint.
	var body_col := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(float(size), float(storeys) * WALL_H, float(size))
	shape.shape = box
	shape.position = Vector3(0, float(storeys) * WALL_H * 0.5, 0)
	body_col.add_child(shape)
	body.add_child(body_col)

func _frame_ring(parent: Node3D, y: float, size: int) -> void:
	var n := int(float(size) / 2.0)
	var half := float(size) / 2.0
	for k in range(n):
		var off := -half + 1.0 + float(k) * WALL_W
		_place(parent, KIT + "Wall_BottomCover.obj", Vector3(off, y, half + 0.1), 0.0)
		_place(parent, KIT + "Wall_BottomCover.obj", Vector3(off, y, -half - 0.1), PI)

# ---------------------------------------------------------------------------
# Market
# ---------------------------------------------------------------------------

func _build_market(parent: Node3D) -> void:
	for i in range(4):
		var x: float = -9.0 + float(i) * 6.0
		var stall := Node3D.new()
		stall.name = "Stall_%d" % i
		stall.position = Vector3(x, 0, -6.5)
		stall.rotation.y = PI  # face the road / entering player
		parent.add_child(stall)
		_place(stall, PROPS + "Stall_Empty.obj", Vector3.ZERO, 0.0, 1.0)
		# Cargo on the stall table.
		_place(stall, PROPS + "Barrel_Apples.obj", Vector3(0.6, 1.0, 0.0), 0.0, 1.0)
		_place(stall, PROPS + "FarmCrate_Carrot.obj", Vector3(-0.4, 1.0, 0.1), 0.3, 1.0)
		# Ground cargo around the stall.
		_place(parent, PROPS + "Barrel.obj", Vector3(x + 1.4, 0, -8.0), 0.0, 1.0)
		_place(parent, PROPS + "Crate_Wooden.obj", Vector3(x - 1.3, 0, -7.6), 0.5, 1.0)
	_place(parent, PROPS + "Stall_Cart_Empty.obj", Vector3(-9.0, 0, -20.0), 0.4, 1.0)
	_place(parent, PROPS + "Stall_Cart_Empty.obj", Vector3(9.0, 0, -20.0), -0.3, 1.0)
	# Benches around the well.
	for i in range(4):
		var ang := float(i) * PI * 0.5
		var bx := sin(ang) * 3.4
		var bz := -16.5 + cos(ang) * 3.4
		_place(parent, PROPS + "Bench.obj", Vector3(bx, 0, bz), ang, 1.0)

# ---------------------------------------------------------------------------
# Props
# ---------------------------------------------------------------------------

func _build_props(parent: Node3D) -> void:
	var front := [
		[-13.0, -27.0, PI * 0.5], [13.0, -27.0, -PI * 0.5],
		[-13.0, -3.0, PI * 0.5], [13.0, -3.0, -PI * 0.5],
		[-13.0, 3.0, PI * 0.5], [13.0, 3.0, -PI * 0.5],
	]
	for i in range(front.size()):
		var f = front[i]
		var p := Vector3(f[0], 0, f[1])
		_place(parent, PROPS + "Barrel.obj", p + Vector3(0, 0, 0), float(i) * 0.7, 1.0)
		_place(parent, PROPS + "Crate_Wooden.obj", p + Vector3(0.8, 0, 0.7), float(i) * 0.5, 1.0)
		_place(parent, PROPS + "Bucket_Wooden_1.obj", p + Vector3(-0.7, 0, 0.6), 0.0, 1.0)
	_place(parent, KIT + "Prop_Wagon.obj", Vector3(22.0, 0, -34.0), -0.3, 0.9)
	_place(parent, KIT + "Prop_Crate.obj", Vector3(20.5, 0, -33.0), 0.2, 0.8)
	# Courtyard tables and chairs beside the inn.
	_place(parent, PROPS + "Table_Large.obj", Vector3(16.5, 0, -8.0), 0.3, 1.0)
	_place(parent, PROPS + "Chair_1.obj", Vector3(15.6, 0, -8.0), -PI * 0.5, 1.0)
	_place(parent, PROPS + "Chair_1.obj", Vector3(17.4, 0, -8.0), PI * 0.5, 1.0)
	_place(parent, PROPS + "Workbench.obj", Vector3(-16.5, 0, -8.0), PI * 0.5, 1.0)
	_place(parent, PROPS + "Anvil.obj", Vector3(-15.2, 0, -8.0), 0.0, 1.0)
	_place(parent, PROPS + "WeaponStand.obj", Vector3(-16.5, 0, -5.5), PI * 0.5, 1.0)
	_place(parent, KIT + "Prop_WoodenFence_Single.obj", Vector3(-24.5, 0, 3), 0.0, 1.0)
	_place(parent, KIT + "Prop_WoodenFence_Single.obj", Vector3(-24.5, 0, -6), 0.0, 1.0)

# ---------------------------------------------------------------------------
# Nature
# ---------------------------------------------------------------------------

func _build_nature(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 730241
	var trees := ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5",
		"Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5",
		"TwistedTree_1", "TwistedTree_2", "TwistedTree_3", "DeadTree_1", "DeadTree_3", "DeadTree_4"]
	var under := ["Bush_Common", "Bush_Common_Flowers", "Fern_1", "Plant_1", "Plant_1_Big",
		"Plant_7", "Plant_7_Big", "Flower_3_Group", "Flower_3_Single", "Flower_4_Group",
		"Flower_4_Single", "Clover_1", "Clover_2", "Mushroom_Common", "Mushroom_Laetiporus"]
	var rocks := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3",
		"Pebble_Round_1", "Pebble_Round_2", "Pebble_Round_3", "Pebble_Square_1", "Pebble_Square_2"]

	# Dense wooded ridge ringing the valley for a strong sense of place.
	for i in range(170):
		var ang: float = rng.randf() * TAU
		var radius: float = rng.randf_range(42.0, 118.0)
		var x: float = sin(ang) * radius
		var z: float = -20.0 + cos(ang) * radius
		if _town_clear(x, z):
			continue
		var tree: String = trees[rng.randi() % trees.size()]
		_place(parent, KIT + tree + ".obj", Vector3(x, _height(x, z), z), rng.randf() * TAU, rng.randf_range(0.85, 1.6))
	# Trees framing the entrance road and the valley edges near town.
	for i in range(46):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var x: float = side * rng.randf_range(24.0, 42.0)
		var z: float = rng.randf_range(-46.0, 30.0)
		if _town_clear(x, z):
			continue
		_place(parent, KIT + trees[rng.randi() % trees.size()] + ".obj", Vector3(x, _height(x, z), z), rng.randf() * TAU, rng.randf_range(0.9, 1.5))
	# Undergrowth: bushes, ferns, flowers, clover, mushrooms and grass everywhere.
	for i in range(150):
		var x: float = rng.randf_range(-44.0, 44.0)
		var z: float = rng.randf_range(-60.0, 30.0)
		if _town_clear(x, z):
			continue
		_place(parent, KIT + under[rng.randi() % under.size()] + ".obj", Vector3(x, _height(x, z), z), rng.randf() * TAU, rng.randf_range(0.7, 1.35))
	# Scattered rock and pebble fields on the slopes.
	for i in range(70):
		var x: float = rng.randf_range(-70.0, 70.0)
		var z: float = rng.randf_range(-80.0, 40.0)
		if _town_clear(x, z):
			continue
		_place(parent, KIT + rocks[rng.randi() % rocks.size()] + ".obj", Vector3(x, _height(x, z), z), rng.randf() * TAU, rng.randf_range(0.6, 1.8))
	# Grass lining the north road and the square edges.
	for i in range(30):
		var z: float = 24.0 - float(i) * 2.0
		for side in [-1.0, 1.0]:
			var x: float = float(side) * rng.randf_range(4.2, 5.2)
			_place(parent, KIT + ("Grass_Common_Short" if i % 2 == 0 else "Grass_Wispy_Tall") + ".obj", Vector3(x, 0.0, z), rng.randf() * TAU, 1.0)
	# Two glowing ancient trees as landmarks.
	_place(parent, MODELS + "ancient_tree.obj", Vector3(-30.0, _height(-30.0, -8.0), -8.0), 0.6, 1.1)
	_place(parent, MODELS + "ancient_tree.obj", Vector3(31.0, _height(31.0, -34.0), -34.0), -0.5, 1.2)

## Keep the road and market square clear of scatter.
func _town_clear(x: float, z: float) -> bool:
	if absf(x) < 6.0 and z > -6.0:
		return true
	if absf(x) < 16.0 and z < -1.0 and z > -26.0:
		return true
	return false

# ---------------------------------------------------------------------------
# Lighting & atmosphere
# ---------------------------------------------------------------------------

func _build_lighting(parent: Node3D) -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.02, 0.012, 0.06)
	sky_mat.sky_horizon_color = Color(0.30, 0.12, 0.30)
	sky_mat.ground_bottom_color = Color(0.04, 0.025, 0.05)
	sky_mat.ground_horizon_color = Color(0.16, 0.09, 0.19)
	sky_mat.sun_angle_max = 12.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.38, 0.60)
	env.ambient_light_energy = 0.42
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.24, 0.13, 0.31)
	env.fog_light_energy = 1.0
	env.fog_density = 0.011
	env.fog_sky_affect = 0.5
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.08
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.98
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.02
	env.adjustment_contrast = 1.08
	env.adjustment_brightness = 0.99
	world_env.environment = env
	parent.add_child(world_env)

	# Low twilight moon lighting the fronts of the town.
	var sun := DirectionalLight3D.new()
	sun.name = "TwilightMoon"
	sun.rotation_degrees = Vector3(-42, -34, 0)
	sun.light_color = Color(0.72, 0.68, 1.0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	parent.add_child(sun)

	# Cool fill from the opposite side so shadowed walls keep their detail
	# instead of reading as flat black silhouettes.
	var fill := DirectionalLight3D.new()
	fill.name = "ArcaneFill"
	fill.rotation_degrees = Vector3(-30, 150, 0)
	fill.light_color = Color(0.45, 0.42, 0.72)
	fill.light_energy = 0.45
	fill.shadow_enabled = false
	parent.add_child(fill)

	# A small number of real lights at key landmarks only — the rest of the
	# town's glow comes from emissive materials, keeping the light count low
	# for the Compatibility renderer on modest GPUs.
	_omni(parent, Vector3(0, 2.2, -16.5), Color(0.3, 0.75, 1.0), 1.6, 10.0)
	_omni(parent, Vector3(0, 5.0, -62), Color(0.55, 0.25, 1.0), 2.0, 16.0)
	_omni(parent, Vector3(5.5, 3.2, -14), Color(1.0, 0.6, 0.28), 1.4, 12.0)
	_omni(parent, Vector3(-5.5, 3.2, -14), Color(1.0, 0.6, 0.28), 1.4, 12.0)
	_omni(parent, Vector3(0, 3.2, -42), Color(1.0, 0.62, 0.3), 1.2, 16.0)

func _omni(parent: Node3D, pos: Vector3, color: Color, energy: float, range_m: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.shadow_enabled = false
	parent.add_child(light)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _group(label: String) -> Node3D:
	var g := Node3D.new()
	g.name = label
	add_child(g)
	return g

func _mesh(path: String) -> Mesh:
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	if not ResourceLoader.exists(path):
		push_warning("Gloamwick: missing mesh " + path)
		return null
	var res: Resource = load(path)
	var mesh: Mesh = null
	if res is Mesh:
		mesh = res
	elif res is PackedScene:
		var inst: Node = (res as PackedScene).instantiate()
		for c in inst.get_children():
			if c is MeshInstance3D:
				mesh = c.mesh
				break
		inst.free()
	if mesh == null:
		return null
	Materials.apply_to_mesh(mesh)
	_mesh_cache[path] = mesh
	return mesh

## Queue a static mesh instance for batching. All Gloamwick meshes are static,
## so instead of one MeshInstance3D node each (hundreds of draw calls) we bake
## their transforms into a single merged mesh per material via _flush().
func _place(parent: Node3D, path: String, pos: Vector3, yaw: float = 0.0, mesh_scale: float = 1.0, pitch: float = 0.0) -> void:
	var mesh := _mesh(path)
	if mesh == null:
		return
	var xform_basis := Basis(Vector3.UP, yaw)
	if pitch != 0.0:
		xform_basis = xform_basis * Basis(Vector3.RIGHT, pitch)
	if mesh_scale != 1.0:
		xform_basis = xform_basis.scaled(Vector3.ONE * mesh_scale)
	# Bake into world space: parent carries the building/stall placement.
	var xform := parent.global_transform * Transform3D(xform_basis, pos)
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s)
		var key: String = mat.resource_name if mat != null else "__default"
		if not _batches.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			_batches[key] = {"tool": tool, "mat": mat}
		(_batches[key]["tool"] as SurfaceTool).append_from(mesh, s, xform)

## Bake every queued instance into one merged MeshInstance3D per material,
## parented to the group node the batch belongs to.
func _flush(parent: Node3D, shadows: bool = true) -> void:
	if _batches.is_empty():
		return
	for key in _batches.keys():
		var entry: Dictionary = _batches[key]
		var tool: SurfaceTool = entry["tool"]
		var merged := tool.commit()
		var mi := MeshInstance3D.new()
		mi.name = "Batch_" + str(key)
		mi.mesh = merged
		mi.material_override = entry["mat"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	_batches.clear()

func _box(parent: Node3D, label: String, pos: Vector3, size: Vector3, mat: StandardMaterial3D, collision: bool) -> Node3D:
	var root: Node3D
	if collision:
		var sb := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		sb.add_child(col)
		root = sb
	else:
		root = Node3D.new()
	root.name = label
	root.position = pos
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var m: StandardMaterial3D = mat.duplicate()
	m.uv1_scale = Vector3(size.x * 0.4, size.z * 0.4, 1.0)
	mi.material_override = m
	mi.name = label
	root.add_child(mi)
	parent.add_child(root)
	return root

func _box_material(texture_path: String, tint: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists(texture_path):
		mat.albedo_texture = load(texture_path)
	mat.albedo_color = tint
	mat.roughness = 0.9
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = tint
		mat.emission_energy_multiplier = energy
	return mat

func _label3d(parent: Node3D, text: String, pos: Vector3, yaw: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.rotation.y = yaw
	label.font_size = 64
	label.pixel_size = 0.006
	label.modulate = Color(1.0, 0.82, 0.55)
	label.outline_size = 12
	label.outline_modulate = Color(0.1, 0.03, 0.08, 0.9)
	parent.add_child(label)