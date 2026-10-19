class_name PlanStrip
extends Control
## The player's plan: numbered slots filled bottom-first with the stamps they
## mean to press. Tap a filled slot to take that stamp back out.

signal slot_tapped(index: int)

var level: Level
## Planned presses: [stamp_index, spot, rot].
var entries: Array = []
var slots := 0
var bad_index := -1
var active_index := -1
var colorblind := false
var _pulse := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 104)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var tw := create_tween().set_loops()
	tw.tween_method(func(v: float) -> void:
		_pulse = v
		if bad_index >= 0 or active_index >= 0:
			queue_redraw(), 0.0, 1.0, 0.4)
	tw.tween_method(func(v: float) -> void:
		_pulse = v
		if bad_index >= 0 or active_index >= 0:
			queue_redraw(), 1.0, 0.0, 0.4)


func refresh() -> void:
	queue_redraw()


func _slot_rect(i: int) -> Rect2:
	var gap := 8.0
	var n := maxi(slots, 1)
	var w := minf((size.x - gap * (n - 1)) / n, size.y - 18)
	var total := w * n + gap * (n - 1)
	var x0 := (size.x - total) * 0.5
	return Rect2(Vector2(x0 + i * (w + gap), 16), Vector2(w, w))


func _draw() -> void:
	var font := UITheme.bold()
	draw_string(font, Vector2(4, 13), "BOTTOM", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.85))
	draw_string(font, Vector2(size.x - 34, 13), "TOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.85))
	for i in slots:
		var r := _slot_rect(i)
		var filled := i < entries.size()
		var sb := UITheme.box(Color(1, 1, 1, 0.95) if filled else Color(1, 1, 1, 0.3), 16)
		if i == bad_index:
			sb.set_border_width_all(4)
			sb.border_color = UITheme.ACCENT.lerp(Color.WHITE, _pulse * 0.4)
		elif i == active_index:
			sb.set_border_width_all(4)
			sb.border_color = UITheme.GOLD
		draw_style_box(sb, r)
		if filled:
			var e: Array = entries[i]
			var stamp := level.stamps[e[0]]
			_draw_mini(stamp, e[2], r)
		var num := str(i + 1)
		var col := UITheme.INK_SOFT if filled else Color(1, 1, 1, 0.9)
		draw_string(font, r.position + Vector2(6, 18), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)


func _draw_mini(stamp: StampDef, rot: int, r: Rect2) -> void:
	var c := r.get_center() + Vector2(2, 3)
	var art := r.size.x * 0.66
	var col := Palettes.color(level.palette, stamp.color)
	var parts := Shapes.polygons(stamp.shape, rot)
	for poly in parts:
		var pts := PackedVector2Array()
		for u in poly:
			pts.append(c + (u - Vector2(0.5, 0.5)) * art)
		draw_colored_polygon(pts, col)
	if stamp.is_eraser():
		for poly in Shapes.merged(stamp.shape, rot):
			var pts := PackedVector2Array()
			for u in poly:
				pts.append(c + (u - Vector2(0.5, 0.5)) * art)
			pts.append(pts[0])
			draw_polyline(pts, UITheme.INK_SOFT, 2.0, true)
	elif colorblind:
		InkSymbols.draw(self, stamp.color, c, art * 0.1, Palettes.contrast(col))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for i in mini(slots, entries.size()):
			if _slot_rect(i).has_point(event.position):
				accept_event()
				slot_tapped.emit(i)
				return
