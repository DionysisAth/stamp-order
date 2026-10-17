class_name FancyBackground
extends Control
## Bright vertical gradient with soft stamp shapes drifting slowly upwards.

const SHAPES := ["star", "circle", "sparkle", "leaf", "petal", "moon", "flower", "cloud", "apple", "sun"]

var colors: Array = [Color("6a4bff"), Color("ff5fa2")]:
	set(v):
		colors = v
		queue_redraw()
var _items: Array = []
var _time := 0.0


func _init(p_colors: Array = []) -> void:
	if not p_colors.is_empty():
		colors = p_colors
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 16:
		_items.append({
			"shape": SHAPES[i % SHAPES.size()],
			"x": rng.randf(),
			"y": rng.randf(),
			"size": rng.randf_range(50.0, 130.0),
			"rot": rng.randf() * TAU,
			"spin": rng.randf_range(-0.25, 0.25),
			"speed": rng.randf_range(10.0, 26.0),
			"alpha": rng.randf_range(0.08, 0.17),
			"wobble": rng.randf() * TAU,
		})


func _process(delta: float) -> void:
	_time += delta
	var h := maxf(size.y, 1.0)
	for it in _items:
		it["y"] -= it["speed"] * delta / h
		it["rot"] += it["spin"] * delta
		if it["y"] < -0.15:
			it["y"] += 1.3
	queue_redraw()


func _draw() -> void:
	var top: Color = colors[0]
	var bottom: Color = colors[1]
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	for it in _items:
		var s: float = it["size"]
		var c := Vector2(it["x"] * size.x + sin(_time * 0.5 + it["wobble"]) * 18.0, it["y"] * size.y)
		var col := Color(1, 1, 1, it["alpha"])
		var rot: float = it["rot"]
		for poly in Shapes.merged(it["shape"], 0):
			var pts := PackedVector2Array()
			for u in poly:
				pts.append(c + ((u - Vector2(0.5, 0.5)) * s).rotated(rot))
			draw_colored_polygon(pts, col)
