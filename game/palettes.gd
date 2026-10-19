class_name Palettes
extends RefCounted
## Curated ink palettes. Colour id 0 is always bare paper; ids 1..8 are inks.

const PAPER := Color("fffdf7")
const PAPER_SHADE := Color("f1ecff")
const INK := Color("2b2347")

## Bright, saturated inks that pop on white paper. Every colour in a palette
## is clearly different in hue so pictures stay readable.
const PALETTES := {
	"garden": ["3ddc6a", "ff4fa3", "ffc61a", "2f9bff", "ff7a1f", "a45bff", "12d6c5", "ff3b3b"],
	"kitchen": ["ff4a3d", "ffd21f", "2ee6a6", "b14dff", "3d7bff", "ff8fab", "a3e635", "ff8a00"],
	"night": ["ffcc00", "4d6bff", "17e3c7", "ff4fa3", "c084fc", "ff8a1f", "7c3aed", "38d1ff"],
	"toybox": ["ff3d7f", "3d5afe", "ffd400", "00c853", "ff6d00", "aa00ff", "00b8d4", "ff1744"],
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
