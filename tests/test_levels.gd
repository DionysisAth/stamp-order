extends TestCase
## Every shipped level loads, is valid, solvable and readable.


func _levels() -> Node:
	return tree.root.get_node("Levels")


func test_sixty_levels_in_three_worlds() -> void:
	var levels := _levels()
	check_eq(levels.worlds.size(), 3, "three worlds")
	check_eq(levels.count(), 60, "sixty levels")
	for w in levels.worlds:
		check_eq(w["levels"].size(), 20, "twenty levels in %s" % w["name"])


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
		var plan: Variant = Solver.solve_level(level)
		check(plan != null, "%s is solvable" % level.id)
		var b := BoardState.new()
		for p in level.solution_presses():
			b.press(level.stamps[p[0]], p[1], p[2])
		check(b.matches(level.target()), "%s solution recreates its target" % level.id)


func test_every_stamp_readable() -> void:
	for level: Level in _levels().all:
		var info := Solver.analyse(level, level.solution_presses())
		for i in level.stamps.size():
			check(int(info["visible"].get(i, 0)) >= 4, "%s stamp %d shows at least 4 cells" % [level.id, i])


func test_world_rules() -> void:
	for level: Level in _levels().all:
		var n := level.stamps.size()
		match level.world:
			1:
				check(n >= 3 and n <= 5, "%s: world 1 uses 3 to 5 stamps" % level.id)
				check(not level.uses_two_spots() and not level.uses_rotation(), "%s: world 1 is order only" % level.id)
			2:
				check(n >= 5 and n <= 7, "%s: world 2 uses 5 to 7 stamps" % level.id)
				check(not level.uses_rotation(), "%s: no rotation before world 3" % level.id)
			3:
				check(n >= 6 and n <= 8, "%s: world 3 uses 6 to 8 stamps" % level.id)
		if level.number % 10 == 0:
			check(level.picture, "%s: every 10th level is a picture level" % level.id)
	check(_levels().get_level(20).uses_two_spots(), "level 21 introduces two spots")
	check(_levels().get_level(40).uses_rotation(), "level 41 introduces rotation")


func test_hints_walk_to_a_win() -> void:
	# Following hints from a blank canvas must always reach the target.
	for level: Level in _levels().all:
		var b := BoardState.new()
		var used := []
		for step in level.stamps.size():
			var h: Variant = Solver.hint(level, b, used)
			if h == null:
				failures.append("%s: hint gave up at step %d" % [level.id, step])
				break
			b.press(level.stamps[h[0]], h[1], h[2])
			used.append(h[0])
		check(b.matches(level.target()), "%s: hints lead to the target" % level.id)
