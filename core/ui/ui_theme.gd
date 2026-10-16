class_name UITheme
extends RefCounted
## The game's look, built in code so it stays in one readable place.

const BG := Color("e8dfcf")
const CARD := Color("fffdf8")
const INK := Color("2e2a26")
const INK_SOFT := Color("6d655c")
const ACCENT := Color("d1495b")
const ACCENT_DARK := Color("a83646")
const GOLD := Color("e9b44c")
const LINE := Color("ded5c6")
const FRAME := Color("8a6a4a")


static func box(color: Color, radius: int = 22, shadow: bool = false, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_color = Color(0.25, 0.2, 0.15, 0.16)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 4)
	if border.a > 0.0:
		sb.set_border_width_all(3)
		sb.border_color = border
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 30

	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.35))
	t.set_stylebox("normal", "Button", box(CARD, 22, true, LINE))
	t.set_stylebox("hover", "Button", box(Color("fffaf0"), 22, true, LINE))
	t.set_stylebox("pressed", "Button", box(Color("efe7da"), 22, false, LINE))
	t.set_stylebox("disabled", "Button", box(Color("ddd3c1"), 22, false))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	# Big red call to action.
	t.set_type_variation("AccentButton", "Button")
	t.set_color("font_color", "AccentButton", Color.WHITE)
	t.set_color("font_hover_color", "AccentButton", Color.WHITE)
	t.set_color("font_pressed_color", "AccentButton", Color.WHITE)
	t.set_color("font_focus_color", "AccentButton", Color.WHITE)
	t.set_font_size("font_size", "AccentButton", 38)
	t.set_stylebox("normal", "AccentButton", box(ACCENT, 26, true))
	t.set_stylebox("hover", "AccentButton", box(ACCENT.lightened(0.06), 26, true))
	t.set_stylebox("pressed", "AccentButton", box(ACCENT_DARK, 26, false))

	# Round icon buttons in the top bar.
	t.set_type_variation("IconButton", "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = t.get_stylebox(state, "Button").duplicate()
		sb.set_corner_radius_all(40)
		t.set_stylebox(state, "IconButton", sb)

	t.set_type_variation("TitleLabel", "Label")
	t.set_font_size("font_size", "TitleLabel", 84)
	t.set_color("font_color", "TitleLabel", INK)
	t.set_type_variation("HeaderLabel", "Label")
	t.set_font_size("font_size", "HeaderLabel", 44)
	t.set_type_variation("SubtleLabel", "Label")
	t.set_font_size("font_size", "SubtleLabel", 26)
	t.set_color("font_color", "SubtleLabel", INK_SOFT)

	t.set_stylebox("panel", "PanelContainer", box(CARD, 28, true))
	t.set_stylebox("panel", "Panel", box(CARD, 28, true))

	return t
