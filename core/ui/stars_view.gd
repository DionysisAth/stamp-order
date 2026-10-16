class_name StarsView
extends Control
## Three stars, filled up to `count`. pop_in() animates them one by one.

var slots := 3
var count := 0:
	set(v):
		count = v
		queue_redraw()
var star_scales: Array[float] = [1.0, 1.0, 1.0]
var empty_color := Color(0.18, 0.16, 0.14, 0.14)


func _init(p_count: int = 0, p_size: Vector2 = Vector2(120, 40)) -> void:
	count = p_count
	custom_minimum_size = p_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var cell := size.x / slots
	var r := minf(cell, size.y) * 0.46
	for i in slots:
		var c := Vector2(cell * (i + 0.5), size.y * 0.5)
		var pts := PackedVector2Array()
		var sr: float = r * star_scales[i]
		for k in 10:
			var rr := sr if k % 2 == 0 else sr * 0.45
			var a := -PI / 2 + PI * k / 5
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		var col := UITheme.GOLD if i < count else empty_color
		if sr > 0.5:
			draw_colored_polygon(pts, col)


func pop_in(p_count: int, delay: float = 0.0) -> void:
	count = p_count
	star_scales = [0.0, 0.0, 0.0]
	queue_redraw()
	var tw := create_tween()
	tw.tween_interval(delay)
	for i in 3:
		tw.tween_method(func(v: float) -> void:
			star_scales[i] = v
			queue_redraw(), 0.0, 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i < p_count:
			tw.tween_callback(Audio.play_click)
