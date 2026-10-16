extends SceneTree
## Level generator (editor-only).
##
##   godot --headless --script res://tools/generate_levels.gd
##
## For every generated slot it builds hundreds of random candidates, rejects
## unreadable or meaningless ones, scores the rest and picks the candidate
## whose score matches the slot's place in the difficulty curve. Hand-made
## tutorial and picture levels come from handmade_levels.gd. Output:
## res://levels/world_N.json (deterministic for a given seed).
##
## Pass `-- --candidates` to also dump every scored candidate to
## res://tools/lab/candidates_wN.json for review in the level lab scene;
## ids listed under "binned" in res://tools/lab/review.json are skipped.

const HANDMADE := preload("res://tools/handmade_levels.gd")
const CANDIDATES_PER_SLOT := 160
const MAX_ATTEMPTS := 6000

const WORLDS := [
	{
		"number": 1, "name": "Garden", "palette": "garden", "seed": 1101,
		"twist": "Order only: find what was pressed last.",
		"shapes": ["leaf", "petal", "sun", "circle", "tulip", "flower", "hedge", "square"],
	},
	{
		"number": 2, "name": "Kitchen", "palette": "kitchen", "seed": 2202,
		"twist": "New: some stamps fit in two spots.",
		"shapes": ["apple", "cup", "plate", "pear", "slice", "toast", "bowl", "egg"],
	},
	{
		"number": 3, "name": "Night Sky", "palette": "night", "seed": 3303,
		"twist": "New: tap and hold a stamp to rotate it.",
		"shapes": ["moon", "star", "cloud", "comet", "planet", "sparkle", "rocket", "circle"],
	},
]

## One entry per level: "hand" for hand-made, otherwise
## [stamps, two_spot_stamps, rotatable_stamps, difficulty 0..1, tip].
const SLOTS := {
	1: [
		"hand", "hand", "hand", "hand", "hand",
		[4, 0, 0, 0.15, ""], [4, 0, 0, 0.3, ""], [4, 0, 0, 0.45, ""], [5, 0, 0, 0.35, ""], "hand",
		[4, 0, 0, 0.5, ""], [5, 0, 0, 0.45, ""], [5, 0, 0, 0.55, ""], [5, 0, 0, 0.65, ""], [3, 0, 0, 0.1, ""],
		[5, 0, 0, 0.7, ""], [5, 0, 0, 0.78, ""], [5, 0, 0, 0.86, ""], [5, 0, 0, 0.95, ""], "hand",
	],
	2: [
		[5, 1, 0, 0.1, "This stamp fits in two spots (see the two dots). Tap it, then tap the spot the target needs."],
		[5, 1, 0, 0.25, ""], [5, 2, 0, 0.3, ""], [6, 1, 0, 0.35, ""], [5, 1, 0, 0.05, ""],
		[6, 2, 0, 0.4, ""], [6, 2, 0, 0.5, ""], [6, 2, 0, 0.55, ""], [7, 2, 0, 0.5, ""], "hand",
		[6, 2, 0, 0.55, ""], [6, 3, 0, 0.6, ""], [7, 2, 0, 0.6, ""], [7, 3, 0, 0.7, ""], [5, 1, 0, 0.1, ""],
		[7, 3, 0, 0.7, ""], [7, 2, 0, 0.8, ""], [7, 3, 0, 0.86, ""], [7, 3, 0, 0.95, ""], "hand",
	],
	3: [
		[6, 0, 1, 0.1, "Stamps with the arrow badge can turn. Tap and hold one to rotate it, then tap to press."],
		[6, 0, 1, 0.25, ""], [6, 0, 2, 0.3, ""], [7, 0, 1, 0.35, ""], [6, 0, 1, 0.05, ""],
		[7, 0, 2, 0.4, ""], [7, 1, 2, 0.45, ""], [7, 0, 2, 0.55, ""], [8, 1, 2, 0.5, ""], "hand",
		[7, 1, 2, 0.55, ""], [7, 0, 3, 0.6, ""], [8, 1, 2, 0.6, ""], [8, 0, 3, 0.7, ""], [6, 0, 1, 0.1, ""],
		[8, 1, 3, 0.7, ""], [8, 2, 2, 0.8, ""], [8, 1, 3, 0.86, ""], [8, 2, 3, 0.95, ""], "hand",
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
			var id := "w%d_%02d" % [world["number"], number]
			var slot: Variant = slots[i]
			var d: Dictionary
			if slot is String:
				d = hand[(world["number"] - 1) * slots.size() + number].duplicate(true)
				d["id"] = id
				d["palette"] = world["palette"]
			else:
				var picked := _generate_slot(world, slot, id, lab)
				d = picked["level"]
				if slot[4] != "":
					d["tip"] = slot[4]
			var level := Level.from_dict(d)
			var issues := _check(level)
			if not issues.is_empty():
				problems += 1
				for issue in issues:
					printerr(issue)
			levels.append(level.to_dict())
			var stats := _stats(level)
			print("%s  stamps=%d depth=%d score=%d%s" % [id, level.stamps.size(), stats["depth"], stats["score"], "  (hand)" if slot is String else ""])
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


func _generate_slot(world: Dictionary, slot: Array, id: String, lab: Array) -> Dictionary:
	var n: int = slot[0]
	var two: int = slot[1]
	var rots: int = slot[2]
	var target: float = slot[3]
	var found := []
	var attempts := 0
	while found.size() < CANDIDATES_PER_SLOT and attempts < MAX_ATTEMPTS:
		attempts += 1
		var d := _candidate(world, n, two, rots, id)
		if d.is_empty():
			continue
		var level := Level.from_dict(d)
		var key := _key(level)
		if _seen.has(key) or _binned.has(key):
			continue
		if not _check(level).is_empty():
			continue
		var stats := _stats(level)
		found.append({"level": d, "score": stats["score"], "key": key})
	if found.is_empty():
		push_error("No valid candidate for %s" % id)
		return {"level": {}}
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] < b["score"])
	var pick: Dictionary = found[roundi(target * (found.size() - 1))]
	_seen[pick["key"]] = true
	for c in found:
		lab.append({"slot": id, "key": c["key"], "score": c["score"], "level": c["level"]})
	return pick


func _key(level: Level) -> String:
	return level.target().cells.hex_encode().sha256_text()


func _candidate(world: Dictionary, n: int, two: int, rots: int, id: String) -> Dictionary:
	var shapes: Array = world["shapes"]
	var colors := range(1, Palettes.COLOR_COUNT + 1)
	_shuffle(colors)
	var cluster := Vector2(rng.randf_range(6.0, 10.0), rng.randf_range(6.0, 10.0))
	var spread := 2.2 + n * 0.25
	var stamps := []
	var rotatable_ok := []
	for i in n:
		var shape: String = shapes[rng.randi() % shapes.size()]
		var size := rng.randi_range(4, 7)
		var pos := _near(cluster, spread, size)
		var s := {"shape": shape, "size": size, "color": colors[i], "placements": [{"x": pos.x, "y": pos.y, "rot": 0}]}
		stamps.append(s)
		if not Shapes.ROTATION_SYMMETRIC.has(shape):
			rotatable_ok.append(i)
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
	var order := range(n)
	_shuffle(order)
	var solution := []
	for si in order:
		solution.append([si, 0])
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
	return {"id": id, "palette": world["palette"], "stamps": stamps, "solution": solution}


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
	for si in level.stamps.size():
		if int(info["visible"].get(si, 0)) < 4:
			problems.append("%s: stamp %d shows only %d cells" % [level.id, si, info["visible"].get(si, 0)])
	var touching := {}
	for a in info["edges"]:
		touching[a] = true
		for b in info["edges"][a]:
			touching[b] = true
	if level.stamps.size() > 1 and touching.size() < level.stamps.size() and not level.picture:
		problems.append("%s: a stamp overlaps nothing" % level.id)
	var colors := {}
	for s in level.stamps:
		if colors.has(s.color):
			problems.append("%s: two stamps share colour %d" % [level.id, s.color])
		colors[s.color] = true
	if not problems.is_empty():
		return problems
	if Solver.solve_level(level) == null:
		problems.append("%s: not solvable" % level.id)
		return problems
	for step in level.solution:
		var si: int = step[0]
		var s := level.stamps[si]
		var real: int = step[1]
		var real_rot: int = s.placements[real]["rot"]
		for spot in s.spot_count():
			if spot != real:
				var filter := {si: _poses_at(s, spot)}
				if Solver.solve_level(level, filter) != null:
					problems.append("%s: stamp %d's decoy spot also solves the level" % [level.id, si])
		if s.rotatable:
			if s.cells(real, s.start_rot) == s.cells(real, real_rot):
				problems.append("%s: stamp %d starts already turned the right way" % [level.id, si])
			elif Solver.solve_level(level, {si: [Vector2i(real, s.start_rot)]}) != null:
				problems.append("%s: stamp %d needs no turning" % [level.id, si])
	return problems


func _poses_at(s: StampDef, spot: int) -> Array:
	var out := []
	for pose in s.poses():
		if pose.x == spot:
			out.append(pose)
	return out


## score = stamps + depth × 2 + small overlaps + placement choices × 2
func _stats(level: Level) -> Dictionary:
	var info := Solver.analyse(level, level.solution_presses())
	var edges: Dictionary = info["edges"]
	var depth := Solver.depth(edges, level.stamps.size())
	var small := 0
	for a in edges:
		for b in edges[a]:
			if int(edges[a][b]) <= 3:
				small += 1
	var choices := 0
	for s in level.stamps:
		if s.spot_count() > 1:
			choices += 1
		if s.rotatable:
			choices += 1
	return {"depth": depth, "score": level.stamps.size() + depth * 2 + small + choices * 2}
