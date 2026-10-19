class_name StackView
extends Control
## Draws prototype B: the sticker pile and the 7-slot tray. Covered stickers
## are dimmed but visible, so players can plan ahead.

signal tile_tapped(index: int)

const TRAY_SLOTS := 7

var level: StackLevel
var present: Array = []
var tray: Array = []
var hint_index := -1
## Stickers in flight to the tray: {type, from, to, t}.
var flights: Array = []
var _shake_index := -1
var _shake := 0.0
var _pulse := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var tw := create_tween().set_loops()
	tw.tween_method(func(v: float) -> void:
		_pulse = v
		if hint_index >= 0:
			queue_redraw(), 0.0, 1.0, 0.45)
	tw.tween_method(func(v: float) -> void:
		_pulse = v
		if hint_index >= 0:
			queue_redraw(), 1.0, 0.0, 0.45)


func tray_rect() -> Rect2:
	var h := minf(size.x / TRAY_SLOTS, 112.0) + 20
	return Rect2(Vector2(0, size.y - h), Vector2(size.x, h))


func _unit() -> float:
	var board_h := tray_rect().position.y - 16
	return minf(size.x / StackLevel.COLS, board_h / StackLevel.ROWS)


func _board_origin() -> Vector2:
	var u := _unit()
	var w := u * StackLevel.COLS
	var h := u * StackLevel.ROWS
	return Vector2((size.x - w) * 0.5, (tray_rect().position.y - 16 - h) * 0.5)


## Screen rect of a tile. Higher layers sit a little up and left, like a
## real stack.
func tile_rect(index: int) -> Rect2:
	var t: Dictionary = level.tiles[index]
	var u := _unit()
	var lift: Vector2 = Vector2(-3, -5) * float(t["z"])
	return Rect2(_board_origin() + Vector2(t["x"], t["y"]) * u + lift, Vector2(u, u) * 2.0)


func slot_rect(i: int) -> Rect2:
	var r := tray_rect()
	var gap := 6.0
	var w := (r.size.x - 20 - gap * (TRAY_SLOTS - 1)) / TRAY_SLOTS
	return Rect2(r.position + Vector2(10 + i * (w + gap), 10), Vector2(w, r.size.y - 20))


func shake(index: int) -> void:
	_shake_index = index
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_shake = sin(v * TAU * 3.0) * 7.0 * (1.0 - v)
		queue_redraw(), 0.0, 1.0, 0.35)
	tw.tween_callback(func() -> void: _shake_index = -1)


func _draw() -> void:
	if level == null:
		return
	var order := []
	for i in level.tiles.size():
		if present[i]:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var ta: Dictionary = level.tiles[a]
		var tb: Dictionary = level.tiles[b]
		return ta["z"] < tb["z"] or (ta["z"] == tb["z"] and ta["y"] < tb["y"]))
	for i in order:
		var r := tile_rect(i)
		if i == _shake_index:
			r.position.x += _shake
		var free := level.is_free(i, present)
		_draw_sticker(r, level.tiles[i]["type"], not free)
		if i == hint_index:
			var sb := StyleBoxFlat.new()
			sb.draw_center = false
			sb.set_corner_radius_all(int(r.size.x * 0.24))
			sb.set_border_width_all(int(5 + 3 * _pulse))
			sb.border_color = UITheme.GOLD
			draw_style_box(sb, r.grow(4))
	# Tray.
	var tr := tray_rect()
	draw_style_box(UITheme.candy(Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.2), 26, 6), tr)
	for i in TRAY_SLOTS:
		var sr := slot_rect(i)
		draw_style_box(UITheme.box(Color(1, 1, 1, 0.3), 16), sr)
		if i < tray.size():
			var side := minf(sr.size.x, sr.size.y)
			_draw_sticker(Rect2(sr.get_center() - Vector2(side, side) * 0.5, Vector2(side, side)), tray[i], false)
	for f in flights:
		var from: Rect2 = f["from"]
		var to: Rect2 = f["to"]
		var t: float = f["t"]
		var r := Rect2(from.position.lerp(to.position, t) - Vector2(0, sin(t * PI) * 60), from.size.lerp(to.size, t))
		_draw_sticker(r, f["type"], false)


func _draw_sticker(r: Rect2, type: int, covered: bool) -> void:
	var info: Dictionary = level.types[type]
	var radius := int(r.size.x * 0.24)
	var shadow := UITheme.box(Color(0.1, 0.03, 0.3, 0.28), radius)
	draw_style_box(shadow, Rect2(r.position + Vector2(0, r.size.y * 0.06), r.size))
	var face := UITheme.box(Color.WHITE, radius)
	face.set_border_width_all(2)
	face.border_color = Color("e4dcf7")
	draw_style_box(face, r)
	var col := Palettes.color(level.palette, info["color"])
	var c := r.get_center()
	var art := r.size.x * 0.7
	for poly in Shapes.polygons(info["shape"], 0):
		var pts := PackedVector2Array()
		for u in poly:
			pts.append(c + (u - Vector2(0.5, 0.5)) * art)
		draw_colored_polygon(pts, col)
	for poly in Shapes.inset(info["shape"], 0, 8, 0.45):
		var pts := PackedVector2Array()
		for u in poly:
			pts.append(c + (u - Vector2(0.5, 0.5)) * art - Vector2(0, r.size.y * 0.02))
		draw_colored_polygon(pts, col.lightened(0.25))
	if covered:
		draw_style_box(UITheme.box(Color(0.12, 0.05, 0.3, 0.45), radius), r)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	# Topmost sticker under the finger.
	var best := -1
	for i in level.tiles.size():
		if present[i] and tile_rect(i).has_point(event.position):
			if best < 0 or level.tiles[i]["z"] > level.tiles[best]["z"] or \
					(level.tiles[i]["z"] == level.tiles[best]["z"] and level.tiles[i]["y"] > level.tiles[best]["y"]):
				best = i
	if best >= 0:
		accept_event()
		tile_tapped.emit(best)
