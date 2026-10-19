extends TestCase
## The two core-loop prototypes: A (free stamping) and B (sticker stack).


func test_free_levels_have_one_answer() -> void:
	var levels := FreeLevels.load_all()
	check_eq(levels.size(), 10, "prototype A has 10 levels")
	for level in levels:
		var uses := []
		for t in level.types:
			uses.append(t["uses"])
		check(FreeSolver.solve(level, BoardState.new().cells, uses) != null, "%s is solvable" % level.id)
		check_eq(FreeSolver.count_decompositions(level), 1, "%s can be made in exactly one way" % level.id)
		var used := {}
		for p in level.solution:
			used[p[0]] = int(used.get(p[0], 0)) + 1
		for t in level.types.size():
			check_eq(used.get(t, 0), level.types[t]["uses"], "%s type %d uses match the solution" % [level.id, t])


func test_free_solver_spots_ambiguity() -> void:
	# A 4×8 bar from 4×4 squares: two presses or three overlapping ones.
	var amb := FreeLevel.from_dict({"stamps": [{"shape": "square", "size": 4, "color": 1, "uses": 3}], "solution": [[0, 0, 0, 0], [0, 0, 4, 0]]})
	check_eq(FreeSolver.count_decompositions(amb), 2, "two ways to make the bar")
	var uniq := FreeLevel.from_dict({"stamps": [{"shape": "square", "size": 4, "color": 1, "uses": 2}], "solution": [[0, 0, 0, 0], [0, 0, 4, 0]]})
	check_eq(FreeSolver.count_decompositions(uniq), 1, "one way with only two uses")


func test_free_hint_after_wrong_press() -> void:
	var level := FreeLevels.load_all()[1]
	var uses := []
	for t in level.types:
		uses.append(t["uses"])
	var b := BoardState.new()
	var last: Array = level.solution[-1]
	level.press(b, last)
	uses[last[0]] -= 1
	check(FreeSolver.hint(level, b, uses) == null, "pressing the top stamp first cannot reach the target")


func test_stack_levels_clear_in_order() -> void:
	for n in range(1, 11):
		var level := StackLevel.generate(n)
		check_eq(level.tiles.size() % 3, 0, "level %d has whole triples" % n)
		var present := []
		for t in level.tiles:
			present.append(true)
		var tray := []
		var ok := true
		for i in level.solution:
			if not level.is_free(i, present):
				failures.append("level %d: sticker %d is covered at its turn" % [n, i])
				ok = false
				break
			present[i] = false
			var type: int = level.tiles[i]["type"]
			tray.append(type)
			if tray.count(type) == 3:
				for k in 3:
					tray.erase(type)
			if tray.size() >= 7:
				failures.append("level %d: the tray fills up on the winning order" % n)
				ok = false
				break
		if ok:
			check(tray.is_empty(), "level %d: winning order empties the tray" % n)


func test_stack_levels_get_bigger() -> void:
	var prev := 0
	for n in range(1, 11):
		var count := StackLevel.generate(n).tiles.size()
		check(count >= prev, "level %d has at least as many stickers as the one before" % n)
		prev = count
