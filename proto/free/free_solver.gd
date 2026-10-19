class_name FreeSolver
extends RefCounted
## Peels a free-stamping target from the top, like Solver, but every stamp
## type can sit anywhere (and turn, if rotatable) and has a number of uses.
## Also counts how many different ways (sets of presses) make the picture,
## which the generator uses to keep only puzzles with one answer.

static var _pose_cache := {}


## All distinct poses of a stamp type: [x, y, rot, PackedInt32Array cells].
static func poses(t: Dictionary) -> Array:
	var key := "%s:%d:%s" % [t["shape"], t["size"], t["rotatable"]]
	if _pose_cache.has(key):
		return _pose_cache[key]
	var out := []
	var seen := {}
	var n: int = t["size"]
	for rot in ([0, 90, 180, 270] if t["rotatable"] else [0]):
		var mask := Shapes.mask(t["shape"], n, rot)
		for y in BoardState.SIZE - n + 1:
			for x in BoardState.SIZE - n + 1:
				var cells := PackedInt32Array()
				for c in mask:
					cells.append(BoardState.index(x + c.x, y + c.y))
				var k := str(cells)
				if seen.has(k):
					continue
				seen[k] = true
				out.append([x, y, rot, cells])
	_pose_cache[key] = out
	return out


## Bottom-up presses [type, x, y, rot] that turn `base` into the target with
## at most `uses_left[type]` presses of each type, or null.
static func solve(level: FreeLevel, base: PackedByteArray, uses_left: Array) -> Variant:
	var target := level.target().cells
	var unresolved := PackedByteArray()
	unresolved.resize(target.size())
	unresolved.fill(1)
	var stack: Array = []
	if _peel(level, target, base, uses_left.duplicate(), unresolved, stack, {}):
		stack.reverse()
		return stack
	return null


static func _ok_here(target: PackedByteArray, base: PackedByteArray, unresolved: PackedByteArray, colors: Dictionary) -> int:
	# 1 = done, 0 = keep going, -1 = dead end.
	var done := 1
	for i in target.size():
		if unresolved[i] == 1 and base[i] != target[i]:
			if not colors.has(target[i]):
				return -1
			done = 0
	return done


static func _colors(level: FreeLevel, uses: Array) -> Dictionary:
	var colors := {}
	for t in uses.size():
		if uses[t] > 0:
			colors[level.types[t]["color"]] = true
	return colors


static func _fits(cells: PackedInt32Array, unresolved: PackedByteArray, target: PackedByteArray, color: int) -> bool:
	var useful := false
	for idx in cells:
		if unresolved[idx] == 1:
			if target[idx] != color:
				return false
			useful = true
	return useful


static func _peel(level: FreeLevel, target: PackedByteArray, base: PackedByteArray, uses: Array, unresolved: PackedByteArray, stack: Array, failed: Dictionary) -> bool:
	var key := str(uses) + unresolved.hex_encode()
	if failed.has(key):
		return false
	var state := _ok_here(target, base, unresolved, _colors(level, uses))
	if state == 1:
		return true
	if state == -1:
		failed[key] = true
		return false
	for t in uses.size():
		if uses[t] <= 0:
			continue
		var color: int = level.types[t]["color"]
		for pose in poses(level.types[t]):
			var cells: PackedInt32Array = pose[3]
			if not _fits(cells, unresolved, target, color):
				continue
			var nu := unresolved.duplicate()
			for idx in cells:
				nu[idx] = 0
			uses[t] -= 1
			stack.append([t, pose[0], pose[1], pose[2]])
			if _peel(level, target, base, uses, nu, stack, failed):
				uses[t] += 1
				return true
			stack.pop_back()
			uses[t] += 1
	failed[key] = true
	return false


## How many different sets of presses make the target from blank paper:
## 0, 1 or 2 (meaning "2 or more"). Returns -1 if the search gave up.
static func count_decompositions(level: FreeLevel, node_cap: int = 60000) -> int:
	var target := level.target().cells
	var base := BoardState.new().cells
	var unresolved := PackedByteArray()
	unresolved.resize(target.size())
	unresolved.fill(1)
	var uses := []
	for t in level.types:
		uses.append(t["uses"])
	var ctx := {"found": {}, "info": {}, "nodes": 0, "cap": node_cap, "gave_up": false}
	_count(level, target, base, uses, unresolved, [], ctx)
	if ctx["gave_up"]:
		return -1
	return mini(ctx["found"].size(), 2)


static func _count(level: FreeLevel, target: PackedByteArray, base: PackedByteArray, uses: Array, unresolved: PackedByteArray, prefix: Array, ctx: Dictionary) -> bool:
	if ctx["found"].size() >= 2 or ctx["gave_up"]:
		return false
	ctx["nodes"] += 1
	if ctx["nodes"] > ctx["cap"]:
		ctx["gave_up"] = true
		return false
	var key := str(uses) + unresolved.hex_encode()
	var sig := _signature(prefix)
	var info: Dictionary = ctx["info"]
	if info.has(key):
		var seen: Dictionary = info[key]
		# Reached the same state through a different set of presses: if it can
		# be finished, that is a second way to make the picture.
		if seen["ok"] and seen["sig"] != sig:
			ctx["found"][sig + "|" + key] = true
		return seen["ok"]
	info[key] = {"sig": sig, "ok": false}
	var state := _ok_here(target, base, unresolved, _colors(level, uses))
	if state == 1:
		ctx["found"][sig] = true
		info[key]["ok"] = true
		return true
	if state == -1:
		return false
	var ok := false
	for t in uses.size():
		if uses[t] <= 0:
			continue
		var color: int = level.types[t]["color"]
		for pose in poses(level.types[t]):
			var cells: PackedInt32Array = pose[3]
			if not _fits(cells, unresolved, target, color):
				continue
			var nu := unresolved.duplicate()
			for idx in cells:
				nu[idx] = 0
			uses[t] -= 1
			prefix.append([t, cells])
			if _count(level, target, base, uses, nu, prefix, ctx):
				ok = true
			prefix.pop_back()
			uses[t] += 1
			if ctx["found"].size() >= 2 or ctx["gave_up"]:
				info[key]["ok"] = ok
				return ok
	info[key]["ok"] = ok
	return ok


static func _signature(prefix: Array) -> String:
	var parts := PackedStringArray()
	for p in prefix:
		parts.append("%d:%s" % [p[0], str(p[1])])
	parts.sort()
	return "/".join(parts)


## Next press to make from the current canvas, or null if the canvas can no
## longer reach the target.
static func hint(level: FreeLevel, board: BoardState, uses_left: Array) -> Variant:
	var plan: Variant = solve(level, board.cells, uses_left)
	if plan == null or plan.is_empty():
		return null
	return plan[0]
