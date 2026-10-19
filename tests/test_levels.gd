extends TestCase
## Every shipped level loads, is valid, solvable, readable and follows the
## world plan: a new mechanic every 5 levels for the first 35 levels.

## Global level number where each mechanic first appears.
const INTRODUCED := {"plan": 5, "spare": 10, "two_spots": 16, "eraser": 21, "twins": 26, "rotation": 31}
const PICTURES := [15, 30, 45, 60]


func _levels() -> Node:
	return tree.root.get_node("Levels")


func _uses(level: Level, mechanic: String) -> bool:
	match mechanic:
		"plan":
			return level.mode == "plan"
		"spare":
			return level.uses_spare()
		"two_spots":
			return level.uses_two_spots()
		"eraser":
			return level.uses_eraser()
		"twins":
			return level.uses_twins()
		"rotation":
			return level.uses_rotation()
	return false


func test_sixty_levels_in_four_worlds() -> void:
	var levels := _levels()
	check_eq(levels.worlds.size(), 4, "four worlds")
	check_eq(levels.count(), 60, "sixty levels")
	for w in levels.worlds:
		check_eq(w["levels"].size(), 15, "fifteen levels in %s" % w["name"])


func test_ids_unique_and_targets_distinct() -> void:
	var ids := {}
	var targets := {}
	for level: Level in _levels().all:
		check(not ids.has(level.id), "duplicate id %s" % level.id)
		ids[level.id] = true
		var key := level.target().cells.hex_encode()
		check(not targets.has(key), "%s has the same picture as %s" % [level.id, targets.get(key, "")])
		targets[key] = level.id


func test_levels_valid_and_solvable() -> void:
	for level: Level in _levels().all:
		for p in level.validate():
			failures.append(p)
		check(Solver.solve_level(level) != null, "%s is solvable" % level.id)


func test_every_used_stamp_readable() -> void:
	for level: Level in _levels().all:
		var info := Solver.analyse(level, level.solution_presses())
		for step in level.solution:
			var si: int = step[0]
			if level.stamps[si].is_eraser():
				check(Solver.erased_cells(level, si) >= 4, "%s eraser %d cuts at least 4 cells" % [level.id, si])
			else:
				check(int(info["visible"].get(si, 0)) >= 4, "%s stamp %d shows at least 4 cells" % [level.id, si])


func test_spares_cannot_be_used() -> void:
	for level: Level in _levels().all:
		for si in level.spares():
			check(Solver.solve_level(level, {}, [si]) == null, "%s spare %d is never part of a solution" % [level.id, si])


func test_mechanics_arrive_every_five_levels() -> void:
	for mechanic in INTRODUCED:
		var first: int = INTRODUCED[mechanic]
		for level: Level in _levels().all:
			var number := level.global_index + 1
			if number < first:
				check(not _uses(level, mechanic), "%s uses %s before level %d" % [level.id, mechanic, first])
			elif number == first:
				check(_uses(level, mechanic), "level %d introduces %s" % [first, mechanic])
				check(level.tip != "", "level %d explains %s with a tip" % [first, mechanic])
	for level: Level in _levels().all:
		var number := level.global_index + 1
		check(level.mode == ("live" if number < 5 else "plan"), "%s: live tutorials 1-4, plan mode after" % level.id)
		check(level.picture == PICTURES.has(number), "%s: picture levels end each world" % level.id)


func test_hard_levels_have_one_answer() -> void:
	# The last puzzle before each world's picture must be fully forced.
	for number in [14, 29, 44, 59]:
		var level: Level = _levels().get_level(number - 1)
		var orders := Solver.count_orders(level, level.solution_presses())
		check(orders <= 2, "%s has %d valid orders (want 1-2)" % [level.id, orders])
	# Generated puzzles never let most orders win.
	for level: Level in _levels().all:
		if level.picture or level.global_index < 5:
			continue
		var orders := Solver.count_orders(level, level.solution_presses())
		check(orders <= 30, "%s has %d valid orders" % [level.id, orders])


func test_hints_walk_to_a_win() -> void:
	# Following hints from a blank canvas must always reach the target.
	for level: Level in _levels().all:
		var b := BoardState.new()
		var used := []
		for step in level.stamps.size():
			if b.matches(level.target()):
				break
			var h: Variant = Solver.hint(level, b, used)
			if h == null:
				failures.append("%s: hint gave up at step %d" % [level.id, step])
				break
			b.press(level.stamps[h[0]], h[1], h[2])
			used.append(h[0])
		check(b.matches(level.target()), "%s: hints lead to the target" % level.id)
