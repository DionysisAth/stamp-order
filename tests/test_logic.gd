extends TestCase
## Board state, undo stack, shapes and solver.


func _level(stamps: Array, solution: Array) -> Level:
	return Level.from_dict({"id": "t", "palette": "garden", "stamps": stamps, "solution": solution})


func _s(shape: String, size: int, color: int, x: int, y: int) -> Dictionary:
	return {"shape": shape, "size": size, "color": color, "placements": [{"x": x, "y": y, "rot": 0}]}


func test_shapes_have_masks_and_rotate_back() -> void:
	for name in Shapes.SHAPE_NAMES:
		for size in [4, 6, 8]:
			var m := Shapes.mask(name, size, 0)
			check(m.size() > 0, "%s/%d has an empty mask" % [name, size])
			check_eq(Shapes.mask(name, size, 90).size(), m.size(), "%s/%d keeps its area when turned" % [name, size])
			check_eq(Shapes.mask(name, size, 360), m, "%s/%d turns back after 360°" % [name, size])
			for c in m:
				check(c.x >= 0 and c.y >= 0 and c.x < size and c.y < size, "%s/%d mask stays inside its box" % [name, size])


func test_merged_outlines_draw() -> void:
	for name in Shapes.SHAPE_NAMES:
		for rot in [0, 90, 180, 270]:
			var parts := Shapes.merged(name, rot)
			check(parts.size() >= 1, "%s/%d has an outline" % [name, rot])
			for p in parts:
				check(Geometry2D.triangulate_polygon(p).size() > 0, "%s/%d outline can be filled" % [name, rot])


func test_symmetric_shapes_are_symmetric() -> void:
	for name in ["square", "circle"]:
		check_eq(Shapes.mask(name, 6, 90), Shapes.mask(name, 6, 0), "%s looks the same turned" % name)
	check(Shapes.mask("moon", 6, 90) != Shapes.mask("moon", 6, 0), "moon changes when turned")


func test_press_is_opaque() -> void:
	var b := BoardState.new()
	var cells_a: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1)]
	var cells_b: Array[Vector2i] = [Vector2i(2, 1), Vector2i(3, 1)]
	b.press_cells(cells_a, 1)
	b.press_cells(cells_b, 2)
	check_eq(b.get_at(1, 1), 1, "uncovered cell keeps first ink")
	check_eq(b.get_at(2, 1), 2, "overlap shows the newest ink")
	check_eq(b.get_at(3, 1), 2, "new cell gets ink")
	check_eq(b.get_at(0, 0), 0, "untouched cell is paper")


func test_undo_restores_board() -> void:
	var level := _level([_s("square", 4, 1, 0, 0), _s("square", 4, 2, 2, 2)], [[0, 0], [1, 0]])
	var b := BoardState.new()
	var presses := []
	var stack := UndoStack.new()
	stack.push(PressCommand.new(b, presses, level.stamps[0], 0, 0, 0))
	var after_first := b.cells.duplicate()
	stack.push(PressCommand.new(b, presses, level.stamps[1], 1, 0, 0))
	check(b.matches(level.target()), "solution presses match the target")
	check(stack.undo(), "undo succeeds")
	check_eq(b.cells, after_first, "undo restores the canvas")
	check_eq(presses.size(), 1, "undo removes the press")
	check(stack.undo(), "second undo succeeds")
	check_eq(b.cells.count(0), b.cells.size(), "board is blank again")
	check(not stack.undo(), "nothing left to undo")


func test_solver_finds_order_and_hints() -> void:
	# Three overlapping squares pressed 0, 1, 2.
	var level := _level([_s("square", 5, 1, 0, 0), _s("square", 5, 2, 3, 3), _s("square", 5, 3, 6, 1)], [[0, 0], [1, 0], [2, 0]])
	var plan: Variant = Solver.solve_level(level)
	check(plan != null, "level is solvable")
	var b := BoardState.new()
	for p in plan:
		b.press(level.stamps[p[0]], p[1], p[2])
	check(b.matches(level.target()), "solver's order recreates the target")
	var h: Variant = Solver.hint(level, BoardState.new(), [])
	check(h != null and h[0] == 0, "first hint is the bottom stamp")
	# Pressing the top stamp first breaks the picture: hint asks for undo.
	var wrong := BoardState.new()
	wrong.press(level.stamps[2], 0, 0)
	check(Solver.hint(level, wrong, [2]) == null, "hint reports a broken order")


func test_independent_stamps_any_order() -> void:
	var level := _level([_s("square", 4, 1, 0, 0), _s("square", 4, 2, 10, 10)], [[0, 0], [1, 0]])
	var b := BoardState.new()
	b.press(level.stamps[1], 0, 0)
	b.press(level.stamps[0], 0, 0)
	check(b.matches(level.target()), "any order works when stamps do not overlap")


func test_two_spots_and_rotation() -> void:
	var decoy := _s("square", 4, 2, 4, 4)
	decoy["placements"].append({"x": 10, "y": 10, "rot": 0})
	var moon := _s("moon", 6, 3, 2, 2)
	moon["rotatable"] = true
	moon["start_rot"] = 0
	moon["placements"][0]["rot"] = 90
	var level := _level([_s("square", 6, 1, 1, 1), decoy, moon], [[0, 0], [1, 1], [2, 0]])
	var plan: Variant = Solver.solve_level(level)
	check(plan != null, "two-spot / rotation level is solvable")
	var found_spot := false
	var found_rot := false
	for p in plan:
		if p[0] == 1:
			found_spot = p[1] == 1
		if p[0] == 2:
			found_rot = level.stamps[2].cells(p[1], p[2]) == level.stamps[2].cells(0, 90)
	check(found_spot, "solver picks the right spot")
	check(found_rot, "solver picks the right rotation")
	check(Solver.solve_level(level, {1: [Vector2i(0, 0)]}) == null, "decoy spot cannot solve the level")


func test_analyse_depth() -> void:
	var level := _level([_s("square", 5, 1, 0, 0), _s("square", 5, 2, 3, 3), _s("square", 5, 3, 6, 6)], [[0, 0], [1, 0], [2, 0]])
	var info := Solver.analyse(level, level.solution_presses())
	check_eq(Solver.depth(info["edges"], 3), 2, "a chain of three has depth 2")
	check_eq(int(info["visible"][2]), 25, "top stamp is fully visible")


func test_spare_stamp_is_left_out() -> void:
	var level := _level([_s("square", 5, 1, 0, 0), _s("circle", 5, 2, 3, 3), _s("square", 4, 3, 10, 10)], [[0, 0], [1, 0]])
	check_eq(level.spares(), [2], "stamp 2 is a spare")
	var plan: Variant = Solver.solve_level(level)
	check(plan != null and plan.size() == 2, "solution leaves the spare out")
	check(Solver.solve_level(level, {}, [2]) == null, "no solution uses the spare")
	var b := BoardState.new()
	b.press(level.stamps[2], 0, 0)
	check(not Solver.reachable(level, b, [2]), "pressing the spare breaks the picture")


func test_eraser_cuts_paper() -> void:
	var eraser := _s("square", 4, 0, 2, 2)
	var level := _level([_s("square", 8, 1, 0, 0), eraser, _s("square", 4, 2, 4, 4)], [[0, 0], [1, 0], [2, 0]])
	check(level.uses_eraser(), "level uses an eraser")
	var t := level.target()
	check_eq(t.get_at(2, 2), 0, "eraser leaves bare paper")
	check_eq(t.get_at(5, 5), 2, "a later stamp covers part of the hole")
	check(Solver.erased_cells(level, 1) >= 4, "eraser cut real ink")
	var plan: Variant = Solver.solve_level(level)
	check(plan != null, "eraser level is solvable")
	check_eq(Solver.first_wrong(level, [[1, 0, 0], [0, 0, 0]]), 0, "erasing blank paper first wastes the eraser")
	check_eq(Solver.first_wrong(level, [[0, 0, 0], [2, 0, 0], [1, 0, 0]]), 1, "pressing the top stamp before the eraser is the mistake")


func test_twin_colours() -> void:
	var level := _level([_s("square", 6, 1, 0, 0), _s("circle", 6, 1, 3, 3), _s("square", 5, 2, 6, 6)], [[0, 0], [1, 0], [2, 0]])
	check(level.uses_twins(), "two stamps share a colour")
	check(Solver.solve_level(level) != null, "twin level is solvable")


func test_count_orders() -> void:
	var chain := _level([_s("square", 5, 1, 0, 0), _s("square", 5, 2, 3, 3), _s("square", 5, 3, 6, 6)], [[0, 0], [1, 0], [2, 0]])
	check_eq(Solver.count_orders(chain, chain.solution_presses()), 1, "a chain has one order")
	var free := _level([_s("square", 4, 1, 0, 0), _s("square", 4, 2, 6, 0), _s("square", 4, 3, 12, 0)], [[0, 0], [1, 0], [2, 0]])
	check_eq(Solver.count_orders(free, free.solution_presses()), 6, "three separate stamps have 3! orders")
