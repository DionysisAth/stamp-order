class_name CanvasView
extends Control
## Draws a sheet of paper and the stamps pressed onto it. Logic lives on the
## hidden 16×16 grid; this view only draws what the state says, using the
## smooth stamp polygons. Used for the play canvas, the target and thumbnails.

signal spot_tapped(spot: int)
signal canvas_tapped

var level: Level
## Presses in order, bottom-up: [stamp_index, spot, rot].
var presses: Array = []
## Grid state, used for colourblind symbols.
var board: BoardState
var colorblind := false
var thumbnail := false
## Stamp whose placement spots are offered (two-spot stamps), or -1.
var ghost_stamp := -1
var ghost_rot := 0
## A pose to highlight for a hint: [stamp, spot, rot], or [].
var hint_pose: Array = []

var press_scale := 1.0:
	set(v):
		press_scale = v
		queue_redraw()
var _pulse := 0.0
var _grain := PackedVector2Array()
var _pulse_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 220:
		_grain.append(Vector2(rng.randf(), rng.randf()))


func _ready() -> void:
	resized.connect(queue_redraw)


func show_level(p_level: Level, p_presses: Array, p_board: BoardState) -> void:
	level = p_level
	presses = p_presses
	board = p_board
	ghost_stamp = -1
	hint_pose = []
	press_scale = 1.0
	_update_pulse()
	queue_redraw()


func show_target(p_level: Level) -> void:
	show_level(p_level, p_level.solution_presses(), p_level.target())
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_ghost(stamp_index: int, rot: int) -> void:
	ghost_stamp = stamp_index
	ghost_rot = rot
	_update_pulse()
	queue_redraw()


func set_hint(pose: Array) -> void:
	hint_pose = pose
	_update_pulse()
	queue_redraw()


func paper_rect() -> Rect2:
	var s := minf(size.x, size.y)
	return Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))


func cell_px() -> float:
	return paper_rect().size.x / BoardState.SIZE


## Thump: the newest stamp settles from 1.15× to 1×, and ink splats out.
func animate_press() -> void:
	if presses.is_empty():
		return
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: press_scale = v, 1.15, 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var p: Array = presses[-1]
	var stamp := level.stamps[p[0]]
	var splat := InkSplat.new()
	splat.position = paper_rect().position + stamp.center(p[1]) * cell_px()
	splat.setup(Palettes.color(level.palette, stamp.color), stamp.size * cell_px())
	add_child(splat)


func shake() -> void:
	var tw := create_tween()
	var base := position
	for i in 6:
		tw.tween_property(self, "position", base + Vector2(10.0 if i % 2 == 0 else -10.0, 0), 0.04)
	tw.tween_property(self, "position", base, 0.04)


func _update_pulse() -> void:
	var want := ghost_stamp >= 0 or not hint_pose.is_empty()
	if want and _pulse_tween == null:
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_method(func(v: float) -> void:
			_pulse = v
			queue_redraw(), 0.0, 1.0, 0.5)
		_pulse_tween.tween_method(func(v: float) -> void:
			_pulse = v
			queue_redraw(), 1.0, 0.0, 0.5)
	elif not want and _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null


func _draw() -> void:
	var r := paper_rect()
	if not thumbnail:
		draw_rect(Rect2(r.position + Vector2(0, 6), r.size), Color(0.3, 0.22, 0.14, 0.12))
	draw_rect(r, Palettes.PAPER)
	if not thumbnail:
		for g in _grain:
			draw_circle(r.position + g * r.size, 1.2, Palettes.PAPER_SHADE)
	if level == null:
		return
	for i in presses.size():
		var p: Array = presses[i]
		var k := press_scale if i == presses.size() - 1 else 1.0
		var stamp := level.stamps[p[0]]
		_draw_stamp(stamp, p[1], p[2], Palettes.color(level.palette, stamp.color), k)
	if colorblind and board != null:
		_draw_symbols(r)
	if ghost_stamp >= 0:
		var stamp := level.stamps[ghost_stamp]
		var col := Palettes.color(level.palette, stamp.color)
		for spot in stamp.spot_count():
			_draw_stamp(stamp, spot, ghost_rot, Color(col, 0.18 + 0.2 * _pulse), 1.0)
			_draw_outline(stamp, spot, ghost_rot, Color(UITheme.INK, 0.55 + 0.35 * _pulse), 3.0)
	if not hint_pose.is_empty():
		var stamp := level.stamps[hint_pose[0]]
		_draw_outline(stamp, hint_pose[1], hint_pose[2], Color(UITheme.GOLD.darkened(0.2), 0.5 + 0.5 * _pulse), 5.0)
	if not thumbnail:
		draw_rect(r, Color(0, 0, 0, 0.06), false, 2.0)


func _stamp_points(stamp: StampDef, spot: int, rot: int, k: float, parts: Array) -> Array:
	var r := paper_rect()
	var cell := cell_px()
	var o := Vector2(stamp.origin(spot))
	var n := float(stamp.size)
	var centre := r.position + (o + Vector2(n, n) * 0.5) * cell
	var out := []
	for poly in parts:
		var pts := PackedVector2Array()
		for u in poly:
			var p: Vector2 = r.position + (o + u * n) * cell
			pts.append(centre + (p - centre) * k)
		out.append(pts)
	return out


## Opaque ink uses the shape's own parts (keeping holes such as a cup
## handle); translucent ghosts use the merged outline so overlapping parts
## do not darken.
func _draw_stamp(stamp: StampDef, spot: int, rot: int, col: Color, k: float) -> void:
	var opaque := col.a >= 1.0
	var fill_parts := Shapes.polygons(stamp.shape, rot) if opaque else Shapes.merged(stamp.shape, rot)
	for pts in _stamp_points(stamp, spot, rot, k, fill_parts):
		draw_colored_polygon(pts, col)
	if opaque and not thumbnail:
		_draw_outline(stamp, spot, rot, col.darkened(0.12), 1.5, k)


func _draw_outline(stamp: StampDef, spot: int, rot: int, col: Color, width: float, k: float = 1.0) -> void:
	for pts in _stamp_points(stamp, spot, rot, k, Shapes.merged(stamp.shape, rot)):
		var closed: PackedVector2Array = pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, col, width, true)


func _draw_symbols(r: Rect2) -> void:
	var cell := cell_px()
	var radius := cell * 0.22
	for y in BoardState.SIZE:
		for x in BoardState.SIZE:
			var id := board.get_at(x, y)
			if id == 0 or (x + y) % 2 == 1:
				continue
			var c := r.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * cell
			InkSymbols.draw(self, id, c, radius, Palettes.contrast(Palettes.color(level.palette, id)))


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	accept_event()
	var r := paper_rect()
	if not r.has_point(event.position):
		canvas_tapped.emit()
		return
	if ghost_stamp < 0:
		canvas_tapped.emit()
		return
	var cell_f: Vector2 = (event.position - r.position) / cell_px()
	var cell := Vector2i(floori(cell_f.x), floori(cell_f.y))
	var stamp := level.stamps[ghost_stamp]
	var best := -1
	var best_d := INF
	for spot in stamp.spot_count():
		if stamp.cells(spot, ghost_rot).has(cell):
			best = spot
			break
		var d := cell_f.distance_to(stamp.center(spot))
		if d < best_d and d <= stamp.size * 0.75:
			best_d = d
			best = spot
	if best >= 0:
		spot_tapped.emit(best)
	else:
		canvas_tapped.emit()
