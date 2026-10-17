class_name IconButton
extends Button
## A round button with a vector icon, so no icon font or image is needed.

const TINTS := {
	"back": Color("2b2347"),
	"hint": Color("ff9f1a"),
	"undo": Color("2f9bff"),
	"restart": Color("ff3d7f"),
	"home": Color("2b2347"),
}

var icon_name := "back"
var badge := ""


static func create(p_icon: String, on_pressed: Callable) -> IconButton:
	var b := IconButton.new()
	b.icon_name = p_icon
	b.theme_type_variation = "IconButton"
	b.custom_minimum_size = Vector2(88, 88)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		Audio.play_click()
		on_pressed.call())
	return b


func _draw() -> void:
	var tint: Color = TINTS.get(icon_name, UITheme.INK)
	var col := tint if not disabled else Color(UITheme.INK, 0.25)
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var w := s * 0.075
	match icon_name:
		"back":
			draw_polyline(PackedVector2Array([P.call(0.58, 0.28), P.call(0.36, 0.5), P.call(0.58, 0.72)]), col, w, true)
		"undo":
			var c: Vector2 = P.call(0.52, 0.54)
			draw_arc(c, s * 0.2, deg_to_rad(-200), deg_to_rad(40), 24, col, w, true)
			_arrow_head(c + Vector2.from_angle(deg_to_rad(-200)) * s * 0.2, Vector2.from_angle(deg_to_rad(-200 - 90)), s * 0.13, col)
		"restart":
			var c: Vector2 = P.call(0.5, 0.52)
			draw_arc(c, s * 0.2, deg_to_rad(-60), deg_to_rad(230), 28, col, w, true)
			_arrow_head(c + Vector2.from_angle(deg_to_rad(-60)) * s * 0.2, Vector2.from_angle(deg_to_rad(-60 + 90)), s * 0.13, col)
		"hint":
			draw_circle(P.call(0.5, 0.43), s * 0.17, col, true, -1.0, true)
			draw_rect(Rect2(P.call(0.42, 0.55), Vector2(0.16, 0.12) * s), col)
			draw_line(P.call(0.42, 0.72), P.call(0.58, 0.72), col, w * 0.8, true)
			draw_circle(P.call(0.45, 0.39), s * 0.05, Color(1, 1, 1, 0.7), true, -1.0, true)
		"home":
			draw_colored_polygon(PackedVector2Array([P.call(0.5, 0.26), P.call(0.74, 0.48), P.call(0.26, 0.48)]), col)
			draw_rect(Rect2(P.call(0.32, 0.47), Vector2(0.36, 0.26) * s), col)
	if badge != "":
		var bc: Vector2 = P.call(0.8, 0.2)
		draw_circle(bc, s * 0.14, UITheme.ACCENT, true, -1.0, true)
		var font := get_theme_default_font()
		var fs := int(s * 0.18)
		var ts := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, bc + Vector2(-ts.x / 2.0, fs * 0.35), badge, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color.WHITE)


func _arrow_head(tip_base: Vector2, dir: Vector2, length: float, col: Color) -> void:
	var side := Vector2(-dir.y, dir.x) * length * 0.6
	draw_colored_polygon(PackedVector2Array([tip_base + dir * length * 0.7, tip_base + side, tip_base - side]), col)
