class_name Minimap
extends Control

## An ornate north-up arcane minimap drawn in the HUD: a decorated compass disc
## with a grid, cardinal points, pulsing points of interest and a player arrow.
## Everything is drawn procedurally so it costs no textures.

var target: Node3D
var pois: Array[Dictionary] = []
var pixels_per_metre := 1.05
var range_metres := 95.0

var _time := 0.0

func set_pois(list: Array[Dictionary]) -> void:
	pois = list
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var centre := size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - 10.0
	if radius <= 4.0:
		return

	# Outer drop shadow + arcane glow halo.
	draw_circle(centre, radius + 8.0, Color(0.28, 0.12, 0.42, 0.16))
	draw_circle(centre, radius + 4.0, Color(0.06, 0.03, 0.10, 0.75))

	# Parchment disc with concentric depth rings.
	draw_circle(centre, radius, Color(0.055, 0.035, 0.10, 0.9))
	draw_circle(centre, radius * 0.72, Color(0.09, 0.05, 0.16, 0.30))
	draw_circle(centre, radius * 0.40, Color(0.12, 0.07, 0.20, 0.30))

	# Faint grid: rings + cross-hairs.
	var grid_col := Color(0.60, 0.42, 0.92, 0.13)
	for i in range(1, 4):
		draw_arc(centre, radius * float(i) / 4.0, 0.0, TAU, 72, grid_col, 1.0, true)
	draw_line(centre - Vector2(radius, 0.0), centre + Vector2(radius, 0.0), grid_col, 1.0, true)
	draw_line(centre - Vector2(0.0, radius), centre + Vector2(0.0, radius), grid_col, 1.0, true)

	# Points of interest (clamped to the disc, pulsing gently).
	if target != null and is_instance_valid(target):
		var ppos: Vector3 = target.global_position
		var limit := radius - 8.0
		for poi in pois:
			var d: Vector3 = poi["pos"] - ppos
			var v := Vector2(d.x, d.z) * pixels_per_metre
			var clamped := false
			if v.length() > limit:
				v = v.normalized() * limit
				clamped = true
			var col: Color = poi.get("color", Color.WHITE)
			var pulse: float = 1.0 + sin(_time * 3.0 + float(poi.get("phase", 0.0))) * 0.18
			var p := centre + v
			draw_circle(p, 6.5 * pulse, Color(col.r, col.g, col.b, 0.18))
			draw_circle(p, 3.4, col)
			draw_arc(p, 3.4, 0.0, TAU, 20, Color(col.r, col.g, col.b, 0.75), 1.5, true)
			if clamped:
				# Small tip pointing toward the off-screen marker.
				var dir := v.normalized()
				draw_circle(p + dir * 7.0, 2.0, Color(col.r, col.g, col.b, 0.9))

	# Player arrow (gold), always centred.
	if target != null and is_instance_valid(target):
		var heading: float = target.rotation.y
		var fwd := Vector2(-sin(heading), -cos(heading))
		var perp := Vector2(fwd.y, -fwd.x)
		draw_circle(centre, 9.0, Color(1.0, 0.9, 0.5, 0.14))
		var tri := PackedVector2Array([
			centre + fwd * 10.0,
			centre - fwd * 5.0 + perp * 6.0,
			centre - fwd * 5.0 - perp * 6.0,
		])
		draw_colored_polygon(tri, Color(1.0, 0.95, 0.62))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.24, 0.13, 0.36), 1.4, true)

	# Decorative rim with tick marks.
	draw_arc(centre, radius, 0.0, TAU, 96, Color(0.42, 0.24, 0.62, 0.95), 2.5, true)
	draw_arc(centre, radius - 3.5, 0.0, TAU, 96, Color(0.72, 0.52, 1.0, 0.35), 1.0, true)
	for i in 12:
		var a := TAU * float(i) / 12.0 - PI * 0.5
		var dir := Vector2(cos(a), sin(a))
		var long := i % 3 == 0
		var inner := radius - (11.0 if long else 6.0)
		draw_line(centre + dir * inner, centre + dir * (radius - 2.0), Color(0.70, 0.50, 1.0, 0.55 if long else 0.3), 2.0 if long else 1.0, true)

	# Cardinal letters.
	var cardinal := {"N": Color(1.0, 0.78, 0.35), "E": Color(0.78, 0.82, 0.95), "S": Color(0.78, 0.82, 0.95), "W": Color(0.78, 0.82, 0.95)}
	var dirs := {"N": Vector2(0, -1), "E": Vector2(1, 0), "S": Vector2(0, 1), "W": Vector2(-1, 0)}
	for k in cardinal.keys():
		var d: Vector2 = dirs[k]
		var text_pos: Vector2 = centre + d * (radius - 1.5)
		var str_size := font.get_string_size(k, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		draw_string(font, text_pos - str_size * 0.5 + Vector2(0, str_size.y * 0.35), k, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, cardinal[k])