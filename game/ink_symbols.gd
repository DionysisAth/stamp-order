class_name InkSymbols
extends RefCounted
## Colourblind-mode symbols: one distinct mark per ink colour id.


static func draw(ci: CanvasItem, color_id: int, center: Vector2, radius: float, col: Color) -> void:
	var w := maxf(1.5, radius * 0.32)
	match Palettes.symbol(color_id):
		"dot":
			ci.draw_circle(center, radius * 0.5, col, true, -1.0, true)
		"ring":
			ci.draw_arc(center, radius * 0.62, 0, TAU, 16, col, w, true)
		"cross":
			var d := Vector2(radius, radius) * 0.6
			ci.draw_line(center - d, center + d, col, w, true)
			ci.draw_line(center + Vector2(-d.x, d.y), center + Vector2(d.x, -d.y), col, w, true)
		"plus":
			ci.draw_line(center - Vector2(radius * 0.8, 0), center + Vector2(radius * 0.8, 0), col, w, true)
			ci.draw_line(center - Vector2(0, radius * 0.8), center + Vector2(0, radius * 0.8), col, w, true)
		"triangle":
			var r := radius * 0.8
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -r), center + Vector2(r * 0.87, r * 0.5), center + Vector2(-r * 0.87, r * 0.5)]), col)
		"square":
			var r := radius * 0.55
			ci.draw_rect(Rect2(center - Vector2(r, r), Vector2(r, r) * 2), col)
		"diamond":
			var r := radius * 0.8
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)]), col)
		"bar":
			ci.draw_line(center - Vector2(radius * 0.8, 0), center + Vector2(radius * 0.8, 0), col, w * 1.3, true)
