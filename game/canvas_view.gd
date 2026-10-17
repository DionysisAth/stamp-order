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
var _pulse_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


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
	var radius := int(r.size.x * (0.05 if thumbnail else 0.035))
	var paper := StyleBoxFlat.new()
	paper.bg_color = Palettes.PAPER
	paper.set_corner_radius_all(radius)
	paper.anti_aliasing = true
	if not thumbnail:
		paper.shadow_color = Color(0.12, 0.04, 0.32, 0.25)
		paper.shadow_size = 14
		paper.shadow_offset = Vector2(0, 8)
	else:
		paper.bg_color = Palettes.PAPER.darkened(0.015)
		paper.set_border_width_all(2)
		paper.border_color = UITheme.LINE
	draw_style_box(paper, r)
	if not thumbnail:
		# A faint dot grid, like craft paper, which also helps line things up.
		var cell := cell_px()
		var dot := maxf(1.2, cell * 0.06)
		for y in range(1, BoardState.SIZE):
			for x in range(1, BoardState.SIZE):
				draw_circle(r.position + Vector2(x, y) * cell, dot, Palettes.PAPER_SHADE, true, -1.0, true)
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
			_draw_stamp(stamp, spot, ghost_rot, Color(col, 0.22 + 0.22 * _pulse), 1.0)
			_draw_outline(stamp, spot, ghost_rot, Color(UITheme.INK, 0.45 + 0.4 * _pulse), 3.5)
	if not hint_pose.is_empty():
		var stamp := level.stamps[hint_pose[0]]
		_draw_outline(stamp, hint_pose[1], hint_pose[2], Color(UITheme.ACCENT, 0.55 + 0.45 * _pulse), 7.0)
		_draw_outline(stamp, hint_pose[1], hint_pose[2], Color(Color.WHITE, 0.9), 2.5)


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


## Opaque ink: a soft drop shadow, the shape's own parts (keeping holes such
## as a cup handle), a lighter glossy inner face and a crisp darker rim.
## Translucent ghosts use the merged outline so overlapping parts do not
## darken.
func _draw_stamp(stamp: StampDef, spot: int, rot: int, col: Color, k: float) -> void:
	if col.a < 1.0:
		for pts in _stamp_points(stamp, spot, rot, k, Shapes.merged(stamp.shape, rot)):
			draw_colored_polygon(pts, col)
		return
	var lift := Vector2(0, cell_px() * (0.1 if thumbnail else 0.16) * k)
	for pts in _stamp_points(stamp, spot, rot, k, Shapes.merged(stamp.shape, rot)):
		var shadow := PackedVector2Array()
		for p in pts:
			shadow.append(p + lift)
		draw_colored_polygon(shadow, Color(0.15, 0.05, 0.35, 0.2))
	for pts in _stamp_points(stamp, spot, rot, k, Shapes.polygons(stamp.shape, rot)):
		draw_colored_polygon(pts, col)
	var gloss := col.lightened(0.22)
	var up := Vector2(0, -cell_px() * 0.07 * k)
	for pts in _stamp_points(stamp, spot, rot, k, Shapes.inset(stamp.shape, rot, stamp.size, 0.32)):
		var moved := PackedVector2Array()
		for p in pts:
			moved.append(p + up)
		draw_colored_polygon(moved, gloss)
	if not thumbnail:
		_draw_outline(stamp, spot, rot, col.darkened(0.18), 2.0, k)


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
