class_name StampButton
extends Control
## One stamp in the tray. Tap to press it; tap-and-hold (or right-click)
## turns a rotatable stamp 90° clockwise, repeating while held.

signal tapped(index: int)
signal rotate_requested(index: int)

const HOLD_SECONDS := 0.4
const REPEAT_SECONDS := 0.5

var index := 0
var stamp: StampDef
var palette := "garden"
var rot := 0
var used := false:
	set(v):
		used = v
		queue_redraw()
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var hinted := false:
	set(v):
		hinted = v
		_update_pulse()
		queue_redraw()
var colorblind := false

var _angle := 0.0
var _press := 1.0
var _pulse := 0.0
var _holding := false
var _hold_fired := false
var _hold_timer: Timer
var _pulse_tween: Tween


func _init(p_index: int = 0, p_stamp: StampDef = null, p_palette: String = "garden") -> void:
	index = p_index
	stamp = p_stamp
	palette = p_palette
	custom_minimum_size = Vector2(118, 118)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if stamp != null:
		rot = stamp.initial_rot()
		_angle = rot


func _ready() -> void:
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.timeout.connect(_on_hold)
	add_child(_hold_timer)
	mouse_exited.connect(_cancel_hold)


func set_rot(r: int, animate: bool = true) -> void:
	var prev := rot
	rot = posmod(r, 360)
	if not animate:
		_angle = rot
		queue_redraw()
		return
	var from := float(prev)
	var to := from + fposmod(rot - prev, 360.0)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_angle = v
		queue_redraw(), from, to, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func bump() -> void:
	var tw := create_tween()
	tw.tween_method(_set_press, 1.12, 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_press(v: float) -> void:
	_press = v
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		accept_event()
		if stamp.rotatable and not used:
			rotate_requested.emit(index)
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if mb.pressed:
		_holding = true
		_hold_fired = false
		_set_press(0.93)
		_hold_timer.start(HOLD_SECONDS)
	elif _holding:
		_holding = false
		_hold_timer.stop()
		_set_press(1.0)
		if not _hold_fired:
			tapped.emit(index)


func _on_hold() -> void:
	if not _holding:
		return
	if stamp.rotatable and not used:
		_hold_fired = true
		rotate_requested.emit(index)
		_hold_timer.start(REPEAT_SECONDS)


func _cancel_hold() -> void:
	if _holding and _hold_fired:
		_holding = false
		_hold_timer.stop()
		_set_press(1.0)


func _update_pulse() -> void:
	if hinted and _pulse_tween == null:
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_method(func(v: float) -> void:
			_pulse = v
			queue_redraw(), 0.0, 1.0, 0.45)
		_pulse_tween.tween_method(func(v: float) -> void:
			_pulse = v
			queue_redraw(), 1.0, 0.0, 0.45)
	elif not hinted and _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
		_pulse = 0.0


func _draw() -> void:
	if stamp == null:
		return
	var c := size * 0.5
	draw_set_transform(c, 0.0, Vector2(_press, _press))
	var half := size * 0.5
	var card := Rect2(-half, size)
	var border := UITheme.LINE
	if hinted:
		border = UITheme.GOLD.lerp(UITheme.ACCENT, _pulse * 0.4)
	elif selected:
		border = UITheme.INK
	var sb := UITheme.box(UITheme.CARD if not used else Color("ece5d9"), 24, not used, border)
	if hinted or selected:
		sb.set_border_width_all(5)
	draw_style_box(sb, card)

	var col := Palettes.color(palette, stamp.color)
	if used:
		col = Color(col, 0.28)
	var art := minf(size.x, size.y) * 0.66
	var angle := deg_to_rad(_angle)
	for poly in Shapes.polygons(stamp.shape, 0):
		var pts := PackedVector2Array()
		for u in poly:
			pts.append(((u - Vector2(0.5, 0.5)) * art).rotated(angle))
		draw_colored_polygon(pts, col)
	if colorblind and not used:
		InkSymbols.draw(self, stamp.color, Vector2.ZERO, art * 0.1, Palettes.contrast(col))

	var s := minf(size.x, size.y)
	if stamp.rotatable and not used:
		_draw_rotate_badge(Vector2(half.x, -half.y) + Vector2(-s * 0.17, s * 0.17), s * 0.12)
	if stamp.spot_count() > 1 and not used:
		var bc := half - Vector2(s * 0.17, s * 0.17)
		draw_circle(bc + Vector2(-s * 0.05, 0), s * 0.04, UITheme.INK, true, -1.0, true)
		draw_circle(bc + Vector2(s * 0.05, 0), s * 0.04, UITheme.INK, true, -1.0, true)
	if used:
		var w := s * 0.06
		draw_polyline(PackedVector2Array([Vector2(-s * 0.16, 0), Vector2(-s * 0.04, s * 0.12), Vector2(s * 0.18, -s * 0.12)]), Color(UITheme.INK, 0.6), w, true)
	draw_set_transform(Vector2.ZERO)


func _draw_rotate_badge(center: Vector2, r: float) -> void:
	draw_circle(center, r * 1.25, UITheme.BG, true, -1.0, true)
	draw_arc(center, r * 0.75, deg_to_rad(-60), deg_to_rad(220), 16, UITheme.INK, r * 0.28, true)
	var tip := center + Vector2.from_angle(deg_to_rad(-60)) * r * 0.75
	var dir := Vector2.from_angle(deg_to_rad(30))
	var side := Vector2(-dir.y, dir.x) * r * 0.4
	draw_colored_polygon(PackedVector2Array([tip + dir * r * 0.5, tip + side, tip - side]), UITheme.INK)
