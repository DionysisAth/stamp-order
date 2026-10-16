class_name Palettes
extends RefCounted
## Curated ink palettes. Colour id 0 is always bare paper; ids 1..8 are inks.

const PAPER := Color("f4efe6")
const PAPER_SHADE := Color("e6dfd2")
const INK := Color("2e2a26")

const PALETTES := {
	"garden": ["5b8e3e", "e07a9f", "f2c14e", "4a90c2", "e8833a", "8e6bbf", "2e7d74", "c8423b"],
	"kitchen": ["d9483b", "f3c94d", "6fbf8e", "7e4e8c", "3d5a99", "f29e6d", "8a9a3b", "7a5236"],
	"night": ["e8c547", "263a73", "2fa39b", "d9627f", "7d8ba6", "ee8b3a", "7b57b8", "6cb4e4"],
}

## Colourblind symbols, one per colour id (index 0 = paper, unused).
const SYMBOLS := ["", "dot", "ring", "cross", "plus", "triangle", "square", "diamond", "bar"]

const COLOR_COUNT := 8


static func color(palette: String, id: int) -> Color:
	if id <= 0:
		return PAPER
	var list: Array = PALETTES.get(palette, PALETTES["garden"])
	return Color(list[(id - 1) % list.size()])


static func symbol(id: int) -> String:
	if id <= 0 or id >= SYMBOLS.size():
		return ""
	return SYMBOLS[id]


## A colour that reads clearly on top of `bg` (for symbols and labels).
static func contrast(bg: Color) -> Color:
	return Color(0, 0, 0, 0.55) if bg.get_luminance() > 0.5 else Color(1, 1, 1, 0.75)
