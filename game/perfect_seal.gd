class_name PerfectSeal
extends Control
## A little gold "PERFECT" stamp that cracks on the first mistake or hint.

var cracked := false


func _init() -> void:
	custom_minimum_size = Vector2(132, 40)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func reset() -> void:
	cracked = false
	rotation = 0.0
	queue_redraw()


func crack() -> void:
	if cracked:
		return
	cracked = true
	pivot_offset = size * 0.5
	var tw := create_tween()
	for i in 4:
		tw.tween_property(self, "rotation", deg_to_rad(8.0 if i % 2 == 0 else -8.0), 0.05)
	tw.tween_property(self, "rotation", deg_to_rad(-4.0), 0.05)
	queue_redraw()


func _draw() -> void:
	var face := Color("b9b3cf") if cracked else UITheme.GOLD
	var edge := Color("8e88a8") if cracked else UITheme.GOLD_DARK
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(UITheme.candy(face, edge, 20, 4), r)
	var font := UITheme.bold()
	var text := "PERFECT"
	var fs := 20
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2((size.x - w) * 0.5 + 8, size.y * 0.5 + 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# Star badge on the left.
	var c := Vector2(16, size.y * 0.5 - 2)
	var pts := PackedVector2Array()
	for k in 10:
		var rr := 8.0 if k % 2 == 0 else 3.6
		var a := -PI / 2 + PI * k / 5
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, Color.WHITE)
	if cracked:
		draw_polyline(PackedVector2Array([Vector2(size.x * 0.55, 2), Vector2(size.x * 0.48, size.y * 0.4),
			Vector2(size.x * 0.58, size.y * 0.55), Vector2(size.x * 0.5, size.y - 4)]), UITheme.INK, 2.5, true)
