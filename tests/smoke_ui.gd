extends SceneTree
## UI smoke test: opens every screen, then plays all 60 levels through the
## real game screen handlers (taps, spot choices, rotations, plans, STAMP!,
## both hint steps, undo).
##   godot --headless --script res://tests/smoke_ui.gd
## Exits 1 on failure. CI also fails the run if any SCRIPT ERROR is printed.

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _open(screen: String, params: Dictionary = {}) -> Node:
	root.get_node("Router").goto(screen, params)
	await _frames(8)
	if current_scene == null:
		failures.append("screen %s did not open" % screen)
	return current_scene


## Uses the real tray handlers: turn the stamp, tap it, pick the spot.
func _queue(game: Node, p: Array) -> void:
	var si: int = p[0]
	var stamp: StampDef = game.level.stamps[si]
	var btn: StampButton = game._buttons[si]
	var turns := 0
	while stamp.cells(p[1], btn.rot) != stamp.cells(p[1], p[2]) and turns < 4:
		game._on_rotate(si)
		turns += 1
	game._on_stamp_tapped(si)
	if stamp.spot_count() > 1:
		game._on_spot_tapped(p[1])


func _run() -> void:
	var save: Node = root.get_node("Save")
	save.path = "user://smoke_save.json"
	save.reset_progress()
	var levels: Node = root.get_node("Levels")

	for screen in ["menu", "levels", "gallery", "settings"]:
		await _open(screen)
	await _open("levels", {"world": 3})

	var game: Node = await _open("game", {"index": 0})
	game.stamp_interval = 0.0
	# Live mode (level 1): hint, a wrong press, undo and restart.
	game._on_hint()
	if game._target.clue_cells.is_empty():
		failures.append("first hint on level 1 should circle a clue on the target")
	game._on_hint()
	if game._canvas.hint_pose.is_empty():
		failures.append("second hint on level 1 should show the stamp")
	var last: int = game.level.solution[-1][0]
	game._on_stamp_tapped(last)
	game._on_hint()
	if game._message.text.find("Undo") < 0:
		failures.append("hint after a wrong press should suggest undo")
	game._on_undo()
	if not game.presses.is_empty():
		failures.append("undo did not lift the stamp")
	game._on_stamp_tapped(0)
	game._on_restart()
	if not game.presses.is_empty():
		failures.append("restart did not clear the paper")

	# Plan mode (level 5): a wrong plan fails and marks the bad slot.
	game.start_level(4, false)
	await _frames(1)
	var sol: Array = game.level.solution_presses()
	for k in range(sol.size() - 1, -1, -1):
		_queue(game, sol[k])
	game._on_stamp_go()
	await _frames(1)
	if game.won or game._strip.bad_index < 0:
		failures.append("a reversed plan should fail and mark a slot")
	if game.failed_runs != 1 or not game._seal.cracked:
		failures.append("a failed run should count and crack the seal")
	game._on_restart()
	if not game.plan.is_empty():
		failures.append("restart should clear the plan")

	for i in levels.count():
		game.start_level(i, false)
		await _frames(1)
		var level: Level = game.level
		for p in level.solution_presses():
			_queue(game, p)
		if game.is_plan_mode():
			if game.plan.size() != level.solution.size():
				failures.append("%s: plan has %d of %d stamps" % [level.id, game.plan.size(), level.solution.size()])
			game._on_stamp_go()
		await _frames(1)
		if not game.won:
			failures.append("%s: playing the solution did not win" % level.id)
		elif game.stars() != 3:
			failures.append("%s: a clean solve should give 3 stars, gave %d" % [level.id, game.stars()])
	# Prototype A: free presses with the tray's rotation.
	await _open("prototypes")
	var fg: Node = await _open("proto_free", {"index": 0})
	for i in fg.levels.size():
		fg.start_level(i)
		await _frames(1)
		for p in fg.level.solution:
			var btn: Node = fg._buttons[p[0]]
			var turns := 0
			while btn.rot != p[3] and turns < 4:
				btn.turn()
				turns += 1
			fg.press(p[0], Vector2i(p[1], p[2]))
		await _frames(1)
		if not fg.won:
			failures.append("free_%02d: playing the solution did not win" % (i + 1))
	fg.start_level(1)
	fg._on_hint()
	if fg._hint.is_empty():
		failures.append("prototype A hint showed nothing")

	# Prototype B: pick stickers in the winning order.
	var stack: Node = await _open("proto_stack", {"index": 0})
	stack.flight_seconds = 0.0
	for n in range(1, 11):
		stack.start_level(n)
		await _frames(1)
		var covered := -1
		for i in stack.level.tiles.size():
			if not stack.level.is_free(i, stack.present):
				covered = i
				break
		if covered >= 0:
			stack.pick(covered)
			if not stack.present[covered]:
				failures.append("stack %d: a covered sticker was picked" % n)
		for i in stack.level.solution:
			stack.pick(i)
		if not stack.won:
			failures.append("stack %d: the winning order did not clear the pile" % n)
	await _open("prototypes")

	await _frames(40)
	if save.unlocked_count() < levels.count():
		failures.append("not every level unlocked after winning them all")
	await _open("gallery")
	await _open("menu")
	save.reset_progress()
	DirAccess.remove_absolute("user://smoke_save.json")

	if failures.is_empty():
		print("SMOKE OK")
		quit(0)
	else:
		for f in failures:
			printerr("SMOKE FAIL: ", f)
		quit(1)
