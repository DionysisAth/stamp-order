extends RefCounted
## Hand-made levels: the first five tutorials and every 10th "picture" level,
## whose stamps form a real image. The generator merges these into the
## world files; ids and palettes are filled in there.


static func _s(shape: String, size: int, color: int, x: int, y: int, rot: int = 0) -> Dictionary:
	return {"shape": shape, "size": size, "color": color, "placements": [{"x": x, "y": y, "rot": rot}]}


static func _order(n: int) -> Array:
	var out := []
	for i in n:
		out.append([i, 0])
	return out


static func levels_for(world: int) -> Dictionary:
	match world:
		1:
			return _garden()
		2:
			return _kitchen()
		3:
			return _night()
	return {}


# Garden palette: 1 green, 2 pink, 3 yellow, 4 blue, 5 orange, 6 purple, 7 teal, 8 red
static func _garden() -> Dictionary:
	return {
		1: {
			"title": "First press",
			"tip": "Tap a stamp to press it onto the paper. Make your paper match the target.",
			"stamps": [_s("square", 7, 4, 2, 5), _s("sun", 7, 3, 7, 2), _s("leaf", 6, 1, 6, 9)],
			"solution": _order(3),
		},
		2: {
			"title": "Opaque ink",
			"tip": "A new stamp covers whatever is under it. The one you can see whole was pressed last.",
			"stamps": [_s("petal", 7, 2, 2, 1), _s("circle", 8, 5, 5, 5), _s("hedge", 6, 6, 9, 9)],
			"solution": _order(3),
		},
		3: {
			"title": "Bottom up",
			"tip": "Work out the bottom stamp and press it first. Undo is free, so try things.",
			"stamps": [_s("square", 6, 7, 2, 2), _s("circle", 6, 3, 5, 4), _s("flower", 6, 8, 8, 6), _s("leaf", 5, 1, 9, 9)],
			"solution": _order(4),
		},
		4: {
			"title": "Need a hand?",
			"tip": "Stuck? The bulb button shows a stamp you can press next.",
			"stamps": [_s("hedge", 7, 1, 2, 7), _s("tulip", 7, 2, 4, 1), _s("petal", 5, 6, 8, 7), _s("sun", 6, 5, 9, 3)],
			"solution": _order(4),
		},
		5: {
			"title": "Breather",
			"tip": "3 stars for a clean solve, 2 with undos, 1 with a hint. Stars never block the way.",
			"stamps": [_s("circle", 7, 4, 1, 2), _s("leaf", 6, 1, 4, 5), _s("square", 6, 8, 9, 7), _s("sun", 5, 3, 7, 10)],
			"solution": _order(4),
		},
		10: {
			"title": "Picture: Flower",
			"picture": true,
			"stamps": [
				_s("bar", 8, 7, 4, 7),
				_s("leaf", 5, 1, 8, 9),
				_s("leaf", 5, 4, 3, 10, 270),
				_s("flower", 8, 2, 4, 1),
				_s("dot", 4, 3, 6, 3),
			],
			"solution": _order(5),
		},
		20: {
			"title": "Picture: Sunny tulip",
			"picture": true,
			"stamps": [
				_s("sun", 7, 3, 9, 0),
				_s("bar", 8, 7, 3, 5),
				_s("leaf", 4, 1, 8, 7),
				_s("tulip", 6, 8, 4, 1),
				_s("hedge", 6, 5, 4, 10),
			],
			"solution": _order(5),
		},
	}


# Kitchen palette: 1 tomato, 2 butter, 3 mint, 4 plum, 5 blueberry, 6 peach, 7 olive, 8 cocoa
static func _kitchen() -> Dictionary:
	var egg := _s("egg", 6, 2, 3, 4)
	egg["placements"].append({"x": 8, "y": 9, "rot": 0})
	return {
		30: {
			"title": "Picture: Breakfast",
			"picture": true,
			"stamps": [
				_s("plate", 14, 5, 1, 1),
				egg,
				_s("dot", 4, 6, 4, 6),
				_s("toast", 6, 8, 8, 3),
				_s("slice", 4, 1, 4, 10),
				_s("dot", 4, 3, 9, 10),
			],
			"solution": [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0], [5, 0]],
		},
		40: {
			"title": "Picture: Tea time",
			"picture": true,
			"stamps": [
				_s("square", 16, 3, 0, 0),
				_s("plate", 10, 5, 3, 6),
				_s("cup", 8, 1, 4, 3),
				_s("pear", 6, 7, 10, 1),
				_s("apple", 5, 4, 11, 9),
				_s("toast", 5, 8, 0, 11),
			],
			"solution": _order(6),
		},
	}


# Night palette: 1 gold, 2 midnight, 3 teal, 4 rose, 5 slate, 6 tangerine, 7 violet, 8 sky
static func _night() -> Dictionary:
	var ear_l := _s("triangle", 4, 6, 4, 4)
	ear_l["rotatable"] = true
	ear_l["start_rot"] = 180
	var ear_r := _s("triangle", 4, 6, 8, 4)
	ear_r["rotatable"] = true
	ear_r["start_rot"] = 90
	ear_r["color"] = 4
	return {
		50: {
			"title": "Picture: Moon cat",
			"picture": true,
			"stamps": [
				_s("square", 16, 2, 0, 0),
				_s("moon", 9, 1, 7, 0),
				ear_l,
				ear_r,
				_s("circle", 8, 5, 4, 6),
				_s("sparkle", 5, 8, 1, 1),
				_s("star", 4, 3, 12, 11),
			],
			"solution": _order(7),
		},
		60: {
			"title": "Picture: Lift-off",
			"picture": true,
			"stamps": [
				_s("square", 16, 2, 0, 0),
				_s("planet", 6, 7, 0, 1),
				_s("moon", 5, 1, 11, 1),
				_s("rocket", 9, 4, 4, 2),
				_s("cloud", 7, 5, 0, 9),
				_s("cloud", 7, 8, 8, 9),
				_s("star", 4, 6, 11, 6),
				_s("sparkle", 4, 3, 2, 8),
			],
			"solution": _order(8),
		},
	}
