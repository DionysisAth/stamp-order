extends SceneTree
## Level generator (editor-only).
##
##   godot --headless --script res://tools/generate_levels.gd
##
## For every generated slot it builds hundreds of random candidates, rejects
## unreadable or meaningless ones, scores the rest and picks the candidate
## whose score matches the slot's place in the difficulty curve. Scores
## reward puzzles that must be reasoned out: few valid orders, long chains
## and sliver clues. Hand-made tutorial and picture levels come from
## handmade_levels.gd. Output: res://levels/world_N.json (deterministic).
##
## Pass `-- --candidates` to also dump every scored candidate to
## res://tools/lab/candidates_wN.json for review in the level lab scene;
## ids listed under "binned" in res://tools/lab/review.json are skipped.

const HANDMADE := preload("res://tools/handmade_levels.gd")
const CANDIDATES_PER_SLOT := 140
const MAX_ATTEMPTS := 9000
const LEVELS_PER_WORLD := 15

const WORLDS := [
	{
		"number": 1, "name": "Garden", "palette": "garden", "seed": 1101,
		"twist": "Read the layers. New: plan, then stamp. Spare stamps.",
		"shapes": ["leaf", "petal", "sun", "circle", "tulip", "flower", "hedge", "square"],
	},
	{
		"number": 2, "name": "Kitchen", "palette": "kitchen", "seed": 2202,
		"twist": "New: two spots, the eraser and twin colours.",
		"shapes": ["apple", "cup", "plate", "pear", "slice", "toast", "bowl", "egg"],
	},
	{
		"number": 3, "name": "Night Sky", "palette": "night", "seed": 3303,
		"twist": "New: tap and hold a stamp to rotate it.",
		"shapes": ["moon", "star", "cloud", "comet", "planet", "sparkle", "rocket", "circle"],
	},
	{
		"number": 4, "name": "Toy Box", "palette": "toybox", "seed": 4404,
		"twist": "Everything at once. Think before you stamp!",
		"shapes": ["star", "moon", "apple", "leaf", "cup", "rocket", "tulip", "cloud", "slice", "petal"],
	},
]

const ERASER_SHAPES := ["circle", "star", "square", "petal", "dot", "sparkle", "flower"]

## One entry per level: "hand" for hand-made, otherwise a dictionary:
## n ink stamps used, two-spot / rotatable stamp counts, spare, eraser and
## twin flags, difficulty 0..1 within the slot's candidates, and a tip.
const SLOTS := {
	1: [
		"hand", "hand", "hand", "hand", "hand",
		{"n": 4, "d": 0.2}, {"n": 4, "d": 0.45}, {"n": 5, "d": 0.45}, {"n": 5, "d": 0.7},
		{"n": 4, "spare": 1, "d": 0.1, "tip": "One stamp in the tray is not in the picture. Leave it out of your plan."},
		{"n": 4, "spare": 1, "d": 0.5}, {"n": 5, "d": 0.8}, {"n": 5, "spare": 1, "d": 0.7}, {"n": 5, "d": 0.95},
		"hand",
	],
	2: [
		{"n": 4, "two": 1, "d": 0.1, "tip": "Stamps with two dots fit in two spots. Tap one, then tap the spot the target needs."},
		{"n": 5, "two": 1, "d": 0.45}, {"n": 5, "two": 2, "d": 0.55}, {"n": 5, "two": 1, "spare": 1, "d": 0.6}, {"n": 5, "d": 0.4},
		{"n": 3, "eraser": 1, "d": 0.1, "tip": "The white stamp is an eraser: it presses bare paper. White holes in the target show where it went, and when."},
		{"n": 4, "eraser": 1, "d": 0.5}, {"n": 5, "eraser": 1, "two": 1, "d": 0.6}, {"n": 5, "two": 2, "d": 0.8}, {"n": 5, "d": 0.6},
		{"n": 4, "twin": 1, "d": 0.1, "tip": "Two stamps share a colour. Read their shapes to tell which one is on top."},
		{"n": 5, "twin": 1, "d": 0.55}, {"n": 5, "twin": 1, "eraser": 1, "d": 0.7}, {"n": 6, "two": 2, "twin": 1, "d": 0.95},
		"hand",
	],
	3: [
		{"n": 4, "rot": 1, "d": 0.1, "tip": "Stamps with the arrow badge can turn. Tap and hold one to rotate it, then add it to your plan."},
		{"n": 5, "rot": 1, "d": 0.45}, {"n": 5, "rot": 2, "d": 0.55}, {"n": 5, "rot": 1, "spare": 1, "d": 0.65}, {"n": 5, "rot": 1, "d": 0.4},
		{"n": 6, "rot": 2, "eraser": 1, "d": 0.55}, {"n": 6, "rot": 1, "twin": 1, "d": 0.6}, {"n": 6, "rot": 2, "two": 1, "d": 0.7},
		{"n": 6, "rot": 2, "spare": 1, "d": 0.8}, {"n": 6, "rot": 1, "eraser": 1, "twin": 1, "d": 0.75},
		{"n": 7, "rot": 2, "d": 0.85}, {"n": 6, "rot": 2, "two": 1, "spare": 1, "d": 0.85}, {"n": 7, "rot": 2, "eraser": 1, "d": 0.9},
		{"n": 7, "rot": 3, "twin": 1, "d": 0.97},
		"hand",
	],
	4: [
		{"n": 6, "two": 1, "rot": 1, "d": 0.5}, {"n": 6, "spare": 1, "eraser": 1, "d": 0.55}, {"n": 6, "twin": 1, "rot": 1, "d": 0.6},
		{"n": 7, "two": 2, "d": 0.65}, {"n": 6, "d": 0.5},
		{"n": 7, "rot": 2, "spare": 1, "d": 0.7}, {"n": 7, "eraser": 1, "two": 1, "d": 0.75}, {"n": 7, "twin": 1, "rot": 2, "d": 0.75},
		{"n": 7, "two": 1, "rot": 1, "spare": 1, "d": 0.85}, {"n": 6, "eraser": 1, "d": 0.6},
		{"n": 8, "rot": 2, "two": 1, "d": 0.88}, {"n": 7, "twin": 1, "eraser": 1, "spare": 1, "d": 0.9}, {"n": 8, "rot": 2, "two": 2, "d": 0.93},
		{"n": 8, "rot": 3, "eraser": 1, "twin": 1, "d": 0.98},
		"hand",
	],
}

var rng := RandomNumberGenerator.new()
var _seen := {}
var _binned := {}


func _initialize() -> void:
	var dump := OS.get_cmdline_user_args().has("--candidates")
	_load_review()
	var problems := 0
	for world in WORLDS:
		rng.seed = world["seed"]
		var levels := []
		var lab := []
		var hand: Dictionary = HANDMADE.levels_for(world["number"])
		var slots: Array = SLOTS[world["number"]]
		for i in slots.size():
			var number: int = i + 1
			var global_number: int = (world["number"] - 1) * LEVELS_PER_WORLD + number
			var id := "w%d_%02d" % [world["number"], number]
			var slot: Variant = slots[i]
			var d: Dictionary
			if slot is String:
				d = hand[global_number].duplicate(true)
				d["id"] = id
				d["palette"] = world["palette"]
			else:
				var picked := _generate_slot(world, slot, id, lab)
				d = picked["level"]
				if slot.get("tip", "") != "":
					d["tip"] = slot["tip"]
			var level := Level.from_dict(d)
			var issues := _check(level)
			if not issues.is_empty():
				problems += 1
				for issue in issues:
					printerr(issue)
			levels.append(level.to_dict())
			var stats := _stats(level)
			print("%s  stamps=%d depth=%d orders=%d slivers=%d score=%d%s" % [
				id, level.stamps.size(), stats["depth"], stats["orders"], stats["slivers"], stats["score"], "  (hand)" if slot is String else ""])
		var out := {
			"world": world["number"], "name": world["name"], "twist": world["twist"],
			"palette": world["palette"], "levels": levels,
		}
		_write_json("res://levels/world_%d.json" % world["number"], out)
		if dump:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/lab"))
			_write_json("res://tools/lab/candidates_w%d.json" % world["number"], {"candidates": lab})
	if problems > 0:
		printerr("%d level(s) failed validation" % problems)
		quit(1)
		return
	print("Levels written.")
	quit(0)


func _load_review() -> void:
	var path := "res://tools/lab/review.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY:
		for key in parsed.get("binned", []):
			_binned[key] = true


func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  ", false) + "\n")
	f.close()


func _generate_slot(world: Dictionary, slot: Dictionary, id: String, lab: Array) -> Dictionary:
	var target: float = slot["d"]
	var found := []
	var attempts := 0
	var wanted := CANDIDATES_PER_SLOT * (2 if target >= 0.9 else 1)
	while found.size() < wanted and attempts < MAX_ATTEMPTS * 2:
		attempts += 1
		var d := _candidate(world, slot, id)
		if d.is_empty():
			continue
		var level := Level.from_dict(d)
		var key := _key(level)
		if _seen.has(key) or _binned.has(key):
			continue
		if not _check(level).is_empty():
			continue
		var stats := _stats(level)
		found.append({"level": d, "score": stats["score"], "key": key, "orders": stats["orders"]})
	if found.is_empty():
		push_error("No valid candidate for %s" % id)
		return {"level": {}}
	# Harder slots only accept puzzles with very few valid orders (one at the
	# top end), so the answer has to be worked out rather than stumbled on.
	var max_orders := maxi(1, roundi(lerpf(12.0, 1.0, target)))
	var strict := found.filter(func(c: Dictionary) -> bool: return c["orders"] <= max_orders)
	if strict.is_empty():
		var fewest: int = found.reduce(func(m: int, c: Dictionary) -> int: return mini(m, c["orders"]), 1 << 30)
		strict = found.filter(func(c: Dictionary) -> bool: return c["orders"] <= maxi(fewest, 2))
	found = strict
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] < b["score"])
	var pick: Dictionary = found[roundi(target * (found.size() - 1))]
	_seen[pick["key"]] = true
	for c in found:
		lab.append({"slot": id, "key": c["key"], "score": c["score"], "level": c["level"]})
	return pick


func _key(level: Level) -> String:
	return level.target().cells.hex_encode().sha256_text()


func _candidate(world: Dictionary, slot: Dictionary, id: String) -> Dictionary:
	var n: int = slot["n"]
	var two: int = slot.get("two", 0)
	var rots: int = slot.get("rot", 0)
	var shapes: Array = world["shapes"]
	var colors := range(1, Palettes.COLOR_COUNT + 1)
	_shuffle(colors)
	var cluster := Vector2(rng.randf_range(6.0, 10.0), rng.randf_range(6.0, 10.0))
	var spread := 2.0 + n * 0.25
	var stamps := []
	var rotatable_ok := []
	var order := range(n)
	_shuffle(order)
	# Build overlap chains on purpose: most stamps land partly on top of the
	# stamp pressed just before them, so the order is forced, not free.
	var chain: float = lerpf(0.45, 0.9, slot["d"])
	var centers := {}
	for k in n:
		var i: int = order[k]
		var shape: String = shapes[rng.randi() % shapes.size()]
		var size := rng.randi_range(5, 8) if n <= 5 else rng.randi_range(4, 7)
		var pos: Vector2i
		if k == 0 or rng.randf() > chain:
			pos = _near(cluster, spread, size)
		else:
			var anchor: int = order[k - 1] if rng.randf() < 0.8 else order[rng.randi() % k]
			var a: Dictionary = centers[anchor]
			var dir := Vector2.from_angle(rng.randf() * TAU)
			var dist: float = (a["size"] + size) * 0.5 * rng.randf_range(0.4, 0.75)
			var c: Vector2 = a["center"] + dir * dist
			pos = Vector2i(clampi(roundi(c.x - size / 2.0), 0, BoardState.SIZE - size), clampi(roundi(c.y - size / 2.0), 0, BoardState.SIZE - size))
		centers[i] = {"center": Vector2(pos) + Vector2(size, size) * 0.5, "size": size}
		stamps.append({})
		if not Shapes.ROTATION_SYMMETRIC.has(shape):
			rotatable_ok.append(i)
		stamps[k] = {"shape": shape, "size": size, "pos": pos, "index": i}
	# Put stamps back in tray order (index i), dropping the helper fields.
	var by_index := []
	by_index.resize(n)
	for e in stamps:
		by_index[e["index"]] = {"shape": e["shape"], "size": e["size"], "color": colors[e["index"]],
			"placements": [{"x": e["pos"].x, "y": e["pos"].y, "rot": 0}]}
	stamps = by_index
	# Twin colours: a stamp takes the colour of another one with a different shape.
	if slot.get("twin", 0) > 0:
		var a := rng.randi() % n
		var b := (a + 1 + rng.randi() % (n - 1)) % n
		if stamps[a]["shape"] == stamps[b]["shape"]:
			return {}
		stamps[b]["color"] = stamps[a]["color"]
	if rotatable_ok.size() < rots:
		return {}
	_shuffle(rotatable_ok)
	for k in rots:
		var s: Dictionary = stamps[rotatable_ok[k]]
		var sol_rot: int = [0, 90, 180, 270][rng.randi() % 4]
		s["placements"][0]["rot"] = sol_rot
		s["rotatable"] = true
		var sol_mask := Shapes.mask(s["shape"], s["size"], sol_rot)
		var starts := []
		for r in [0, 90, 180, 270]:
			if Shapes.mask(s["shape"], s["size"], r) != sol_mask:
				starts.append(r)
		if starts.is_empty():
			return {}
		s["start_rot"] = starts[rng.randi() % starts.size()]
	var solution := []
	for si in order:
		solution.append([si, 0])
	# The eraser goes somewhere after the first two stamps, so it cuts ink
	# and later stamps can cover part of its hole.
	if slot.get("eraser", 0) > 0:
		var size := rng.randi_range(4, 5)
		var pos := _near(cluster, spread * 0.6, size)
		stamps.append({"shape": ERASER_SHAPES[rng.randi() % ERASER_SHAPES.size()], "size": size, "color": 0,
			"placements": [{"x": pos.x, "y": pos.y, "rot": 0}]})
		var at := rng.randi_range(2, n)
		solution.insert(at, [stamps.size() - 1, 0])
	var picks := range(n)
	_shuffle(picks)
	for k in two:
		var si: int = picks[k]
		var s: Dictionary = stamps[si]
		var real: Dictionary = s["placements"][0]
		var decoy := {}
		for tries in 30:
			var p := _near(cluster, spread + 2.0, s["size"])
			if absi(p.x - real["x"]) + absi(p.y - real["y"]) >= 4:
				decoy = {"x": p.x, "y": p.y, "rot": real["rot"]}
				break
		if decoy.is_empty():
			return {}
		if rng.randf() < 0.5:
			s["placements"] = [decoy, real]
			for step in solution:
				if step[0] == si:
					step[1] = 1
		else:
			s["placements"] = [real, decoy]
	# A spare looks like it belongs: on harder levels it shares a colour with
	# a used stamp, so only its shape gives it away.
	if slot.get("spare", 0) > 0:
		var shape: String = shapes[rng.randi() % shapes.size()]
		var size := rng.randi_range(4, 6)
		var pos := _near(cluster, spread, size)
		var color: int = colors[n] if slot["d"] < 0.3 else stamps[rng.randi() % n]["color"]
		stamps.append({"shape": shape, "size": size, "color": color, "placements": [{"x": pos.x, "y": pos.y, "rot": 0}]})
		# Shuffle the spare into the tray so it is not always last.
		var at := rng.randi() % stamps.size()
		var spare: Dictionary = stamps.pop_back()
		stamps.insert(at, spare)
		for step in solution:
			if step[0] >= at:
				step[0] += 1
	_recentre(stamps)
	return {"id": id, "palette": world["palette"], "stamps": stamps, "solution": solution}


## Chained placement wanders, so slide the whole composition (decoy spots
## included) to the middle of the paper.
func _recentre(stamps: Array) -> void:
	var lo := Vector2i(BoardState.SIZE, BoardState.SIZE)
	var hi := Vector2i.ZERO
	for s in stamps:
		for p in s["placements"]:
			lo = Vector2i(mini(lo.x, p["x"]), mini(lo.y, p["y"]))
			hi = Vector2i(maxi(hi.x, p["x"] + s["size"]), maxi(hi.y, p["y"] + s["size"]))
	var shift := Vector2i((BoardState.SIZE - hi.x - lo.x) / 2, (BoardState.SIZE - hi.y - lo.y) / 2)
	for s in stamps:
		for p in s["placements"]:
			p["x"] += shift.x
			p["y"] += shift.y


func _near(center: Vector2, spread: float, size: int) -> Vector2i:
	var x := roundi(center.x + rng.randfn(0.0, spread) - size / 2.0)
	var y := roundi(center.y + rng.randfn(0.0, spread) - size / 2.0)
	return Vector2i(clampi(x, 0, BoardState.SIZE - size), clampi(y, 0, BoardState.SIZE - size))


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


## Rejects levels that are unreadable or whose twist means nothing.
func _check(level: Level) -> PackedStringArray:
	var problems := level.validate()
	if not problems.is_empty():
		return problems
	var presses := level.solution_presses()
	var info := Solver.analyse(level, presses)
	var used := {}
	for p in presses:
		used[p[0]] = true
		var s := level.stamps[p[0]]
		if s.is_eraser():
			var erased := Solver.erased_cells(level, p[0])
			if erased < 4:
				problems.append("%s: eraser %d only cuts %d cells" % [level.id, p[0], erased])
		elif int(info["visible"].get(p[0], 0)) < 4:
			problems.append("%s: stamp %d shows only %d cells" % [level.id, p[0], info["visible"].get(p[0], 0)])
	var touching := {}
	for a in info["edges"]:
		touching[a] = true
		for b in info["edges"][a]:
			touching[b] = true
	if presses.size() > 1 and touching.size() < presses.size() and not level.picture:
		problems.append("%s: a stamp overlaps nothing" % level.id)
	if not problems.is_empty():
		return problems
	if Solver.solve_level(level) == null:
		problems.append("%s: not solvable" % level.id)
		return problems
	for si in level.spares():
		if Solver.solve_level(level, {}, [si]) != null:
			problems.append("%s: spare stamp %d can be used in a solution" % [level.id, si])
	for step in level.solution:
		var si: int = step[0]
		var s := level.stamps[si]
		var real: int = step[1]
		var real_rot: int = s.placements[real]["rot"]
		for spot in s.spot_count():
			if spot != real and Solver.solve_level(level, {si: _poses_at(s, spot)}, [si]) != null:
				problems.append("%s: stamp %d's decoy spot also solves the level" % [level.id, si])
		if s.rotatable:
			if s.cells(real, s.start_rot) == s.cells(real, real_rot):
				problems.append("%s: stamp %d starts already turned the right way" % [level.id, si])
			elif Solver.solve_level(level, {si: [Vector2i(real, s.start_rot)]}, [si]) != null:
				problems.append("%s: stamp %d needs no turning" % [level.id, si])
	return problems


func _poses_at(s: StampDef, spot: int) -> Array:
	var out := []
	for pose in s.poses():
		if pose.x == spot:
			out.append(pose)
	return out


## Higher scores need more reasoning: few valid orders (forced chains),
## sliver clues (an order decided by 1 or 2 cells), depth and twists.
func _stats(level: Level) -> Dictionary:
	var presses := level.solution_presses()
	var info := Solver.analyse(level, presses)
	var edges: Dictionary = info["edges"]
	var depth := Solver.depth(edges, level.stamps.size())
	var slivers := 0
	for a in edges:
		for b in edges[a]:
			if int(edges[a][b]) <= 2:
				slivers += 1
	var orders := Solver.count_orders(level, presses)
	var twists := 0
	for s in level.stamps:
		if s.spot_count() > 1:
			twists += 1
		if s.rotatable:
			twists += 1
	if level.uses_spare():
		twists += 1
	if level.uses_eraser():
		twists += 1
	if level.uses_twins():
		twists += 1
	var score := presses.size() + depth * 3 + slivers * 2 + twists * 2 - int(round(3.0 * log(float(orders)) / log(2.0)))
	return {"depth": depth, "orders": orders, "slivers": slivers, "score": score}
