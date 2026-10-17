class_name ProgressPips
extends Control
## A row of dots: one per stamp, filled as stamps are pressed.

var total := 0:
	set(v):
		total = v
		queue_redraw()
var done := 0:
	set(v):
		done = v
		queue_redraw()
var color := UITheme.ACCENT


func _init() -> void:
	custom_minimum_size = Vector2(0, 26)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := 9.0
	var gap := 26.0
	for i in total:
		var c := Vector2(r + 2 + i * gap, size.y * 0.5)
		if i < done:
			draw_circle(c, r, color, true, -1.0, true)
			draw_circle(c - Vector2(2, 2.5), r * 0.35, Color(1, 1, 1, 0.55), true, -1.0, true)
		else:
			draw_circle(c, r, UITheme.CARD_EDGE, true, -1.0, true)
