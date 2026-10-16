class_name SwitchButton
extends Button
## A full-width settings row with a large on/off switch drawn on the right.


func _init(p_text: String = "", on: bool = false) -> void:
	text = p_text
	toggle_mode = true
	button_pressed = on
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, 92)
	add_theme_font_size_override("font_size", 32)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(c, UITheme.INK)
	toggled.connect(func(_on: bool) -> void: queue_redraw())


func _draw() -> void:
	var track := Vector2(96, 52)
	var r := Rect2(Vector2(size.x - track.x - 4, (size.y - track.y) * 0.5), track)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(track.y / 2))
	sb.anti_aliasing = true
	sb.bg_color = UITheme.ACCENT if button_pressed else UITheme.LINE
	draw_style_box(sb, r)
	var knob_x := r.end.x - track.y * 0.5 if button_pressed else r.position.x + track.y * 0.5
	draw_circle(Vector2(knob_x, r.get_center().y), track.y * 0.4, Color.WHITE, true, -1.0, true)
