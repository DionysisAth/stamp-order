class_name UITheme
extends RefCounted
## The game's look, built in code so it stays in one readable place:
## bright gradient backdrops, white cards, chunky raised "candy" buttons and
## the rounded Fredoka font.

const INK := Color("2b2347")
const INK_SOFT := Color("6e6790")
const CARD := Color("ffffff")
const CARD_EDGE := Color("dcd5f5")
const LINE := Color("e9e4fb")
const ACCENT := Color("ff3d7f")
const ACCENT_DARK := Color("c81e5b")
const SUN := Color("ffc933")
const SUN_DARK := Color("e59400")
const GOLD := Color("ffc61a")
const GOLD_DARK := Color("e08a00")
const FRAME := Color("ff9f43")
const MINT := Color("2ee6a6")
const SKY := Color("4dabff")
const BG := Color("7b5cff")

## Gradient backdrops (top, bottom) per screen or world.
const GRADIENTS := {
	"menu": [Color("6a4bff"), Color("ff5fa2")],
	"garden": [Color("16c79a"), Color("5ad1ff")],
	"kitchen": [Color("ff8a3d"), Color("ff4f8b")],
	"night": [Color("2b2f8f"), Color("9b4dff")],
	"gallery": [Color("ff9f43"), Color("ff4f8b")],
	"settings": [Color("3d8bff"), Color("8b5cff")],
}

## World accent colours (tiles, badges), by world number.
const WORLD_COLORS := [Color("16c79a"), Color("ff7a3d"), Color("7c4dff")]

static var _font: Font
static var _bold: Font


static func font() -> Font:
	if _font == null:
		_font = _variation(500)
	return _font


static func bold() -> Font:
	if _bold == null:
		_bold = _variation(650)
	return _bold


static func _variation(weight: int) -> Font:
	var base: Font = load("res://fonts/Fredoka.ttf")
	var v := FontVariation.new()
	v.base_font = base
	var ts := TextServerManager.get_primary_interface()
	v.variation_opentype = {ts.name_to_tag("wght"): weight}
	return v


static func gradient(key: String) -> Array:
	return GRADIENTS.get(key, GRADIENTS["menu"])


static func world_gradient(world: int) -> Array:
	return gradient(["garden", "kitchen", "night"][clampi(world - 1, 0, 2)])


static func world_color(world: int) -> Color:
	return WORLD_COLORS[clampi(world - 1, 0, 2)]


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
		sb.shadow_color = Color(0.12, 0.05, 0.3, 0.22)
		sb.shadow_size = 12
		sb.shadow_offset = Vector2(0, 6)
	if border.a > 0.0:
		sb.set_border_width_all(3)
		sb.border_color = border
	return sb


## A raised button face: the darker bottom edge makes it look pressable.
static func candy(face: Color, edge: Color, radius: int = 28, depth: int = 8, pressed: bool = false) -> StyleBoxFlat:
	var sb := box(face, radius, not pressed)
	sb.border_color = edge
	sb.border_width_bottom = 2 if pressed else depth
	sb.expand_margin_top = 0
	if pressed:
		sb.content_margin_top += depth - 2
	if not pressed:
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 5)
		sb.shadow_color = Color(0.1, 0.03, 0.25, 0.25)
	return sb


static func label_settings(size: int, color: Color = Color.WHITE, outline: int = 0, outline_color: Color = INK, shadow: bool = false, use_bold: bool = true) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = bold() if use_bold else font()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = outline_color
	if shadow:
		ls.shadow_size = 0
		ls.shadow_color = Color(0.1, 0.03, 0.3, 0.35)
		ls.shadow_offset = Vector2(0, max(3, size / 14))
	return ls


static func _candy_states(t: Theme, type: String, face: Color, edge: Color, radius: int, depth: int) -> void:
	t.set_stylebox("normal", type, candy(face, edge, radius, depth))
	t.set_stylebox("hover", type, candy(face.lightened(0.06), edge, radius, depth))
	t.set_stylebox("pressed", type, candy(face.darkened(0.04), edge, radius, depth, true))
	t.set_stylebox("disabled", type, candy(Color(face, 0.55), Color(edge, 0.4), radius, depth))
	t.set_stylebox("focus", type, StyleBoxEmpty.new())


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 30

	t.set_color("font_color", "Label", INK)

	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.35))
	t.set_font("font", "Button", bold())
	t.set_font_size("font_size", "Button", 32)
	_candy_states(t, "Button", CARD, CARD_EDGE, 28, 8)

	# Big call to action.
	t.set_type_variation("AccentButton", "Button")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "AccentButton", Color.WHITE)
	t.set_font_size("font_size", "AccentButton", 44)
	t.set_color("font_outline_color", "AccentButton", ACCENT_DARK)
	t.set_constant("outline_size", "AccentButton", 6)
	_candy_states(t, "AccentButton", ACCENT, ACCENT_DARK, 34, 10)

	t.set_type_variation("SunButton", "Button")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "SunButton", INK)
	t.set_font_size("font_size", "SunButton", 48)
	_candy_states(t, "SunButton", SUN, SUN_DARK, 36, 12)

	# Round icon buttons in the top bar.
	t.set_type_variation("IconButton", "Button")
	_candy_states(t, "IconButton", CARD, CARD_EDGE, 44, 7)

	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", bold())
	t.set_font_size("font_size", "TitleLabel", 84)
	t.set_color("font_color", "TitleLabel", Color.WHITE)
	t.set_type_variation("HeaderLabel", "Label")
	t.set_font("font", "HeaderLabel", bold())
	t.set_font_size("font_size", "HeaderLabel", 44)
	t.set_color("font_color", "HeaderLabel", Color.WHITE)
	t.set_color("font_shadow_color", "HeaderLabel", Color(0.1, 0.03, 0.3, 0.35))
	t.set_constant("shadow_offset_y", "HeaderLabel", 3)
	t.set_constant("shadow_offset_x", "HeaderLabel", 0)
	t.set_type_variation("SubtleLabel", "Label")
	t.set_font_size("font_size", "SubtleLabel", 26)
	t.set_color("font_color", "SubtleLabel", INK_SOFT)
	t.set_type_variation("OnColorLabel", "Label")
	t.set_font_size("font_size", "OnColorLabel", 28)
	t.set_color("font_color", "OnColorLabel", Color.WHITE)
	t.set_color("font_shadow_color", "OnColorLabel", Color(0.1, 0.03, 0.3, 0.3))
	t.set_constant("shadow_offset_y", "OnColorLabel", 2)
	t.set_constant("shadow_offset_x", "OnColorLabel", 0)

	t.set_stylebox("panel", "PanelContainer", box(CARD, 32, true))
	t.set_stylebox("panel", "Panel", box(CARD, 32, true))

	# Dialogs (reset progress confirmation).
	t.set_stylebox("panel", "AcceptDialog", box(CARD, 28, true))
	t.set_stylebox("embedded_border", "Window", box(CARD, 28, true))
	t.set_color("title_color", "Window", INK)
	t.set_font("title_font", "Window", bold())
	return t
