extends SceneTree
## Generates the 10 levels of prototype A (free stamping):
##   godot --headless --script res://tools/generate_free.gd
## Writes res://proto/free/levels.json. Keeps only pictures that can be made
## in exactly one way, and prefers ones with more hidden (covered) area,
## since working out what is underneath is the puzzle.

const OUT := "res://proto/free/levels.json"
const SHAPES := ["circle", "square", "leaf", "petal", "tulip", "triangle", "star", "moon", "cloud", "apple", "cup", "slice", "bowl", "rocket", "comet", "hedge", "flower"]
const ASYMMETRIC := ["leaf", "petal", "tulip", "triangle", "moon", "cloud", "apple", "cup", "slice", "bowl", "rocket", "comet"]

## presses: how many times each type is used, e.g. [1, 2] = two types, the
## second used twice. rot: stamps may need turning.
const SPECS := [
	{"presses": [1, 1], "rot": false, "title": "Drag and press", "tip": "Drag a stamp from the tray onto the paper and let go to press it. Make the paper match the target."},
	{"presses": [1, 1, 1], "rot": false, "title": "Layers", "tip": "Where does each stamp go, and which one went first?"},
	{"presses": [2, 1], "rot": false, "title": "Twice", "tip": "The ×2 stamp can be pressed twice. One blob of colour might be two presses."},
	{"presses": [2, 1, 1], "rot": false, "title": "Hidden parts", "tip": "Part of a stamp can hide under another. Picture what's underneath."},
	{"presses": [1, 1, 1], "rot": true, "title": "Turn it", "tip": "Tap a stamp in the tray to turn it before you drag it."},
	{"presses": [2, 1, 1], "rot": true, "title": "", "tip": ""},
	{"presses": [1, 1, 1, 1], "rot": true, "title": "", "tip": ""},
	{"presses": [2, 2, 1], "rot": false, "title": "", "tip": ""},
	{"presses": [2, 1, 1, 1], "rot": true, "title": "", "tip": ""},
	{"presses": [2, 2, 1, 1], "rot": true, "title": "", "tip": ""},
]

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 7070
	var levels := []
	for i in SPECS.size():
		var spec: Dictionary = SPECS[i]
		var best := {}
		var best_score := -1
		var valid := 0
		var attempts := 0
		while valid < 8 and attempts < 400:
			attempts += 1
			var d := _candidate(spec, i)
			if d.is_empty():
				continue
			var level := FreeLevel.from_dict(d)
			var hidden := _check(level)
			if hidden < 0:
				continue
			valid += 1
			if hidden > best_score:
				best_score = hidden
				best = d
		if best.is_empty():
			printerr("No valid level for slot %d" % (i + 1))
			quit(1)
			return
		levels.append(best)
		print("free_%02d  presses=%d hidden=%d (from %d valid, %d attempts)" % [i + 1, best["solution"].size(), best_score, valid, attempts])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"levels": levels}, "  ", false) + "\n")
	f.close()
	print("Wrote ", OUT)
	quit(0)


func _candidate(spec: Dictionary, index: int) -> Dictionary:
	var counts: Array = spec["presses"]
	var colors := range(1, Palettes.COLOR_COUNT + 1)
	_shuffle(colors)
	var pool: Array = (ASYMMETRIC if spec["rot"] else SHAPES).duplicate()
	_shuffle(pool)
	var types := []
	var presses := []
	for t in counts.size():
		var shape: String = pool[t]
		types.append({"shape": shape, "size": rng.randi_range(6, 9), "color": colors[t], "uses": counts[t],
			"rotatable": spec["rot"] and not Shapes.ROTATION_SYMMETRIC.has(shape)})
		for k in counts[t]:
			presses.append(t)
	_shuffle(presses)
	# Each press lands partly on the one before it.
	var solution := []
	var prev_center := Vector2(8, 8)
	for k in presses.size():
		var t: Dictionary = types[presses[k]]
		var n: int = t["size"]
		var c := prev_center
		if k > 0:
			c += Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.5, 4.5)
		var x := clampi(roundi(c.x - n / 2.0), 0, BoardState.SIZE - n)
		var y := clampi(roundi(c.y - n / 2.0), 0, BoardState.SIZE - n)
		var rot: int = [0, 90, 180, 270][rng.randi() % 4] if t["rotatable"] else 0
		solution.append([presses[k], x, y, rot])
		prev_center = Vector2(x, y) + Vector2(n, n) * 0.5
	var palette: String = ["garden", "kitchen", "night", "toybox"][index % 4]
	return {"id": "free_%02d" % (index + 1), "title": spec["title"], "tip": spec["tip"], "palette": palette,
		"stamps": types, "solution": solution}


## Returns the number of hidden cells (covered parts of stamps), or -1 when
## the level is unreadable or has more than one answer.
func _check(level: FreeLevel) -> int:
	var top := {}
	var covered := 0
	var total := 0
	for i in level.solution.size():
		var p: Array = level.solution[i]
		for c in FreeLevel.cells_of(level.types[p[0]], p[1], p[2], p[3]):
			if top.has(c):
				covered += 1
			top[c] = i
	var visible := {}
	for c in top:
		visible[top[c]] = int(visible.get(top[c], 0)) + 1
		total += 1
	for i in level.solution.size():
		if int(visible.get(i, 0)) < 5:
			return -1
	if total < 50 or total > 200:
		return -1
	if covered < 4:
		return -1
	if FreeSolver.count_decompositions(level) != 1:
		return -1
	return covered


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
