class_name Solver
extends RefCounted
## Reads layers backwards. Whatever is fully visible in the target was pressed
## last, so we peel stamps off the top: a stamp can be peeled when every cell
## it covers that is still unexplained shows its colour. When the remaining
## stamps are all peeled, the cells nobody explained must already be correct
## on the base canvas. Reversing the peel order gives a bottom-up solution.
##
## Works for any base canvas, which is what makes hints possible mid-level:
## solve(target, current canvas, unpressed stamps).


## Returns a bottom-up list of presses [stamp_index, spot, rot] that turns
## `base` into `target` using exactly the stamps in `remaining`, or null.
static func solve(level: Level, target: PackedByteArray, base: PackedByteArray, remaining: Array, pose_filter: Dictionary = {}) -> Variant:
	var unresolved := PackedByteArray()
	unresolved.resize(target.size())
	unresolved.fill(1)
	var poses := {}
	for si in remaining:
		poses[si] = _distinct_poses(level.stamps[si], pose_filter.get(si, []))
	var stack: Array = []
	var failed := {}
	if _peel(level, target, base, remaining.duplicate(), unresolved, poses, stack, failed):
		stack.reverse()
		return stack
	return null


## Full solve from a blank canvas: the "is this level solvable" check.
static func solve_level(level: Level, pose_filter: Dictionary = {}) -> Variant:
	var blank := BoardState.new()
	return solve(level, level.target().cells, blank.cells, range(level.stamps.size()), pose_filter)


## Next stamp to press from the current state, as [stamp, spot, rot], or null
## when the current canvas can no longer reach the target (undo needed).
static func hint(level: Level, board: BoardState, used: Array) -> Variant:
	var remaining := []
	for i in level.stamps.size():
		if not used.has(i):
			remaining.append(i)
	if remaining.is_empty():
		return null
	var plan: Variant = solve(level, level.target().cells, board.cells, remaining)
	if plan == null:
		return null
	return plan[0]


static func _distinct_poses(stamp: StampDef, only: Array) -> Array:
	var out := []
	var seen := {}
	for pose in stamp.poses():
		if not only.is_empty() and not only.has(pose):
			continue
		var cells := stamp.cells(pose.x, pose.y)
		var key := str(cells)
		if seen.has(key):
			continue
		seen[key] = true
		out.append([pose, cells])
	return out


static func _peel(level: Level, target: PackedByteArray, base: PackedByteArray, remaining: Array, unresolved: PackedByteArray, poses: Dictionary, stack: Array, failed: Dictionary) -> bool:
	if remaining.is_empty():
		for i in target.size():
			if unresolved[i] == 1 and base[i] != target[i]:
				return false
		return true
	var key := str(remaining) + unresolved.hex_encode()
	if failed.has(key):
		return false
	# Every unexplained wrong cell needs a remaining stamp of its colour.
	var colors := {}
	for si in remaining:
		colors[level.stamps[si].color] = true
	for i in target.size():
		if unresolved[i] == 1 and base[i] != target[i] and not colors.has(target[i]):
			failed[key] = true
			return false
	for si in remaining:
		var color: int = level.stamps[si].color
		for entry in poses[si]:
			var cells: Array[Vector2i] = entry[1]
			var ok := true
			for c in cells:
				var idx := BoardState.index(c.x, c.y)
				if unresolved[idx] == 1 and target[idx] != color:
					ok = false
					break
			if not ok:
				continue
			var next_unresolved := unresolved.duplicate()
			for c in cells:
				next_unresolved[BoardState.index(c.x, c.y)] = 0
			var next_remaining := remaining.duplicate()
			next_remaining.erase(si)
			var pose: Vector2i = entry[0]
			stack.append([si, pose.x, pose.y])
			if _peel(level, target, base, next_remaining, next_unresolved, poses, stack, failed):
				return true
			stack.pop_back()
	failed[key] = true
	return false


# --- analysis used by the generator and tests -------------------------------

## "A before B" edges for a sequence of presses: for every cell, the stamp
## showing there must come after every other stamp that covers it.
## Returns {edges: {a: {b: overlap_cells}}, visible: {stamp: cell_count}}.
static func analyse(level: Level, presses: Array) -> Dictionary:
	var top := PackedInt32Array()
	top.resize(BoardState.SIZE * BoardState.SIZE)
	top.fill(-1)
	var covers := {}
	for p in presses:
		var cells := level.stamps[p[0]].cells(p[1], p[2])
		covers[p[0]] = cells
		for c in cells:
			top[BoardState.index(c.x, c.y)] = p[0]
	var edges := {}
	var visible := {}
	for p in presses:
		visible[p[0]] = 0
	for i in top.size():
		if top[i] >= 0:
			visible[top[i]] += 1
	for p in presses:
		for c in covers[p[0]]:
			var t := top[BoardState.index(c.x, c.y)]
			if t != p[0]:
				if not edges.has(p[0]):
					edges[p[0]] = {}
				edges[p[0]][t] = int(edges[p[0]].get(t, 0)) + 1
	return {"edges": edges, "visible": visible}


## Longest chain of "before" edges (0 when no stamp overlaps another).
static func depth(edges: Dictionary, count: int) -> int:
	var memo := {}
	var best := 0
	for i in count:
		best = maxi(best, _longest_from(i, edges, memo))
	return best


static func _longest_from(node: int, edges: Dictionary, memo: Dictionary) -> int:
	if memo.has(node):
		return memo[node]
	var best := 0
	for nxt in edges.get(node, {}):
		best = maxi(best, 1 + _longest_from(nxt, edges, memo))
	memo[node] = best
	return best
