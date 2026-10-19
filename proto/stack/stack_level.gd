class_name StackLevel
extends RefCounted
## Prototype B level: a pile of stickers. Positions are in half-tile units
## (a sticker covers 2×2 units); z is the layer. Built backwards from a known
## winning order, so every generated pile can be cleared.

const SPECS := [
	{"types": 3, "triples": 1, "mix": 1, "tip": "Tap a sticker nothing covers. It goes to the tray; three alike clear. Don't fill all 7 slots!"},
	{"types": 4, "triples": 1, "mix": 2, "tip": "Dimmed stickers are covered. Peek at what's underneath before you pick."},
	{"types": 4, "triples": 2, "mix": 2, "tip": ""},
	{"types": 5, "triples": 2, "mix": 2, "tip": ""},
	{"types": 6, "triples": 2, "mix": 2, "tip": "Plan ahead: keep the tray from filling up with singles."},
	{"types": 6, "triples": 2, "mix": 3, "tip": ""},
	{"types": 7, "triples": 2, "mix": 3, "tip": ""},
	{"types": 8, "triples": 2, "mix": 3, "tip": ""},
	{"types": 8, "triples": 2, "mix": 3, "tip": ""},
	{"types": 9, "triples": 2, "mix": 3, "tip": "The last one. Good luck!"},
]
const COLS := 12
const ROWS := 14
const TYPE_SHAPES := ["circle", "star", "leaf", "apple", "moon", "cup", "tulip", "rocket", "flower", "petal", "slice", "cloud"]
const TYPE_COLORS := [1, 2, 3, 4, 5, 6, 7, 8]

var number := 1
var tip := ""
var palette := "toybox"
## [{shape, color}] per type.
var types: Array = []
## [{type, x, y, z}]
var tiles: Array = []
## A known winning pick order (tile indexes), used by tests and hints.
var solution: Array = []


static func generate(level_number: int) -> StackLevel:
	var spec: Dictionary = SPECS[level_number - 1]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5050 + level_number * 97
	var l := StackLevel.new()
	l.number = level_number
	l.tip = spec["tip"]
	l.palette = ["toybox", "garden", "kitchen", "night"][(level_number - 1) % 4]
	var shapes := TYPE_SHAPES.duplicate()
	_shuffle(shapes, rng)
	for t in spec["types"]:
		l.types.append({"shape": shapes[t], "color": TYPE_COLORS[t % TYPE_COLORS.size()]})
	# Winning order: triples, `mix` of them interleaved at a time, so a
	# perfect player never holds more than 2 × mix stickers.
	var triples := []
	for t in spec["types"]:
		for k in spec["triples"]:
			triples.append(t)
	_shuffle(triples, rng)
	var order := []
	var i := 0
	while i < triples.size():
		var group := []
		for k in spec["mix"]:
			if i + k < triples.size():
				for c in 3:
					group.append(triples[i + k])
		i += spec["mix"]
		_shuffle(group, rng)
		order.append_array(group)
	# Place backwards: the last sticker picked goes down first; each new one
	# lands on top of whatever it overlaps, so the order above always works.
	var placed := []
	for k in range(order.size() - 1, -1, -1):
		var pos := Vector2i.ZERO
		if placed.is_empty() or rng.randf() < 0.25:
			pos = Vector2i(rng.randi_range(0, COLS - 2), rng.randi_range(0, ROWS - 2))
		else:
			var near: Dictionary = placed[rng.randi() % placed.size()]
			pos = Vector2i(clampi(near["x"] + rng.randi_range(-2, 2), 0, COLS - 2), clampi(near["y"] + rng.randi_range(-2, 2), 0, ROWS - 2))
		var z := 0
		for p in placed:
			if overlaps(p, pos):
				z = maxi(z, p["z"] + 1)
		placed.append({"type": order[k], "x": pos.x, "y": pos.y, "z": z})
	placed.reverse()
	l.tiles = placed
	l.solution = range(placed.size())
	return l


static func overlaps(tile: Dictionary, pos: Vector2i) -> bool:
	return absi(tile["x"] - pos.x) < 2 and absi(tile["y"] - pos.y) < 2


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


## A tile is free when no tile still on the board above it overlaps it.
func is_free(index: int, present: Array) -> bool:
	var t: Dictionary = tiles[index]
	for j in tiles.size():
		if j != index and present[j]:
			var o: Dictionary = tiles[j]
			if o["z"] > t["z"] and overlaps(o, Vector2i(t["x"], t["y"])):
				return false
	return true
