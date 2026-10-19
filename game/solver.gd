class_name Solver
extends RefCounted
## Reads layers backwards. Whatever is fully visible in the target was pressed
## last, so we peel stamps off the top: a stamp can be peeled when every cell
## it covers that is still unexplained shows its colour. When the remaining
## stamps are all peeled, the cells nobody explained must already be correct
## on the base canvas. Reversing the peel order gives a bottom-up solution.
##
## Works for any base canvas, which is what makes hints possible mid-level:
## solve(target, current canvas, unpressed stamps). Stamps are optional, so a
## spare that is not in the picture is simply never peeled.


## Returns a bottom-up list of presses [stamp_index, spot, rot] that turns
## `base` into `target` using some of the stamps in `remaining` (each at most
## once; spares may be left out), or null. Every stamp in `required` must be
## used. `pose_filter` limits a stamp to the given Vector2i(spot, rot) poses.
static func solve(level: Level, target: PackedByteArray, base: PackedByteArray, remaining: Array, pose_filter: Dictionary = {}, required: Array = []) -> Variant:
	var unresolved := PackedByteArray()
	unresolved.resize(target.size())
	unresolved.fill(1)
	var poses := {}
	for si in remaining:
		poses[si] = _distinct_poses(level.stamps[si], pose_filter.get(si, []))
	var stack: Array = []
	var failed := {}
	if _peel(level, target, base, remaining.duplicate(), unresolved, poses, required, stack, failed):
		stack.reverse()
		return stack
	return null


## Full solve from a blank canvas: the "is this level solvable" check.
static func solve_level(level: Level, pose_filter: Dictionary = {}, required: Array = []) -> Variant:
	var blank := BoardState.new()
	return solve(level, level.target().cells, blank.cells, range(level.stamps.size()), pose_filter, required)


## True when the target can still be reached from `board` with the unused
## stamps.
static func reachable(level: Level, board: BoardState, used: Array) -> bool:
	return solve(level, level.target().cells, board.cells, _unused(level, used)) != null


## Next stamp to press from the current state, as [stamp, spot, rot], or null
## when the current canvas can no longer reach the target (undo needed) or
## already matches it.
static func hint(level: Level, board: BoardState, used: Array) -> Variant:
	var plan: Variant = solve(level, level.target().cells, board.cells, _unused(level, used))
	if plan == null or plan.is_empty():
		return null
	return plan[0]


## Index of the first press in `presses` after which the target can no longer
## be reached, or -1 when every prefix is still fine.
static func first_wrong(level: Level, presses: Array) -> int:
	var b := BoardState.new()
	var used := []
	for i in presses.size():
		var p: Array = presses[i]
		b.press(level.stamps[p[0]], p[1], p[2])
		used.append(p[0])
		if not reachable(level, b, used):
			return i
	return -1


static func _unused(level: Level, used: Array) -> Array:
	var out := []
	for i in level.stamps.size():
		if not used.has(i):
			out.append(i)
	return out


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


static func _peel(level: Level, target: PackedByteArray, base: PackedByteArray, remaining: Array, unresolved: PackedByteArray, poses: Dictionary, required: Array, stack: Array, failed: Dictionary) -> bool:
	var needs_required := false
	for r in required:
		if remaining.has(r):
			needs_required = true
			break
	var key := str(remaining) + unresolved.hex_encode()
	if failed.has(key):
		return false
	# Done when every unexplained cell is already right on the base canvas.
	var colors := {}
	for si in remaining:
		colors[level.stamps[si].color] = true
	var all_right := true
	for i in target.size():
		if unresolved[i] == 1 and base[i] != target[i]:
			all_right = false
			# Every unexplained wrong cell needs a remaining stamp of its colour.
			if not colors.has(target[i]):
				failed[key] = true
				return false
	if all_right and not needs_required:
		return true
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
			if _peel(level, target, base, next_remaining, next_unresolved, poses, required, stack, failed):
				return true
			stack.pop_back()
	failed[key] = true
	return false


## How many different press orders of the given presses give the same
## picture (linear extensions of the "before" graph). 1 means the order is
## completely forced; big numbers mean most orders work.
static func count_orders(level: Level, presses: Array, cap: int = 100000) -> int:
	var info := analyse(level, presses)
	var edges: Dictionary = info["edges"]
	var ids := []
	for p in presses:
		ids.append(p[0])
	var n := ids.size()
	var pred := PackedInt32Array()
	pred.resize(n)
	for a in edges:
		for b in edges[a]:
			pred[ids.find(b)] |= 1 << ids.find(a)
	var ways := PackedInt64Array()
	ways.resize(1 << n)
	ways[0] = 1
	for mask in 1 << n:
		if ways[mask] == 0:
			continue
		for j in n:
			if mask & (1 << j) == 0 and (pred[j] & mask) == pred[j]:
				ways[mask | (1 << j)] = mini(ways[mask | (1 << j)] + ways[mask], cap)
	return ways[(1 << n) - 1]


# --- analysis used by the generator and tests -------------------------------

## Ink cells an eraser actually removed in the solution: paper in the target
## where something had been pressed before the eraser.
static func erased_cells(level: Level, eraser: int) -> int:
	var inked := {}
	var top := {}
	for p in level.solution_presses():
		for c in level.stamps[p[0]].cells(p[1], p[2]):
			if p[0] == eraser:
				if inked.has(c):
					top[c] = true
			else:
				inked[c] = true
				top.erase(c)
	var t := level.target()
	var count := 0
	for c in top:
		if t.get_at(c.x, c.y) == 0:
			count += 1
	return count


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
