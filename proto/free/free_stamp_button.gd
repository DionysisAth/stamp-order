class_name FreeStampButton
extends Control
## A stamp type in prototype A's tray. Tap to turn it (if it can turn),
## drag it onto the paper to press it there. Shows how many uses are left.

signal turned(type: int)

var type_index := 0
var info: Dictionary
var palette := "garden"
var rot := 0
var uses_left := 1:
	set(v):
		uses_left = v
		queue_redraw()
var hinted := false:
	set(v):
		hinted = v
		queue_redraw()
var _angle := 0.0
var _dragging := false


func _init(p_index: int = 0, p_info: Dictionary = {}, p_palette: String = "garden") -> void:
	type_index = p_index
	info = p_info
	palette = p_palette
	custom_minimum_size = Vector2(124, 124)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _get_drag_data(_at: Vector2) -> Variant:
	if uses_left <= 0:
		return null
	_dragging = true
	var preview := Control.new()
	set_drag_preview(preview)
	return {"free_type": type_index}


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_dragging = false


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
		return
	if _dragging:
		return
	accept_event()
	if info.get("rotatable", false) and uses_left > 0:
		turn()


func turn() -> void:
	var from := float(rot)
	rot = (rot + 90) % 360
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_angle = v
		queue_redraw(), from, from + 90.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play_rotate()
	turned.emit(type_index)


func _draw() -> void:
	var half := size * 0.5
	var empty := uses_left <= 0
	var sb := UITheme.box(Color(1, 1, 1, 0.45), 26) if empty else UITheme.candy(UITheme.CARD, UITheme.CARD_EDGE, 26, 7)
	if hinted and not empty:
		sb.set_border_width_all(6)
		sb.border_width_bottom = 9
		sb.border_color = UITheme.GOLD
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var col := Palettes.color(palette, info["color"])
	if empty:
		col = Color(col, 0.3)
	var art := minf(size.x, size.y) * 0.62
	var angle := deg_to_rad(_angle)
	for poly in Shapes.polygons(info["shape"], 0):
		var pts := PackedVector2Array()
		for u in poly:
			pts.append(half + ((u - Vector2(0.5, 0.5)) * art).rotated(angle))
		draw_colored_polygon(pts, col)
	if not empty:
		for poly in Shapes.inset(info["shape"], 0, info["size"], 0.32):
			var pts := PackedVector2Array()
			for u in poly:
				pts.append(half + ((u - Vector2(0.5, 0.5)) * art).rotated(angle) - Vector2(0, 2))
			draw_colored_polygon(pts, col.lightened(0.22))
	# Uses badge.
	var font := UITheme.bold()
	var text := "×%d" % uses_left
	var bc := Vector2(size.x - 26, 22)
	draw_circle(bc, 18, UITheme.INK if not empty else Color(UITheme.INK, 0.3), true, -1.0, true)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(font, bc + Vector2(-w * 0.5, 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	if info.get("rotatable", false) and not empty:
		var rc := Vector2(24, 22)
		draw_circle(rc, 16, UITheme.ACCENT, true, -1.0, true)
		draw_arc(rc, 9, deg_to_rad(-60), deg_to_rad(220), 14, Color.WHITE, 3.5, true)
