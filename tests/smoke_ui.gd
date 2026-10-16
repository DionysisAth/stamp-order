extends SceneTree
## UI smoke test: opens every screen, then plays all 60 levels through the
## real game screen handlers (taps, spot choices, rotations, hint, undo).
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


func _run() -> void:
	var save: Node = root.get_node("Save")
	save.path = "user://smoke_save.json"
	save.reset_progress()
	var levels: Node = root.get_node("Levels")

	for screen in ["menu", "levels", "gallery", "settings"]:
		await _open(screen)
	await _open("levels", {"world": 3})

	var game: Node = await _open("game", {"index": 0})
	# Hint, a wrong press, undo and restart on the first level.
	game._on_hint()
	var h: Array = game._canvas.hint_pose
	if h.is_empty():
		failures.append("hint on level 1 showed nothing")
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

	for i in levels.count():
		game.start_level(i, false)
		await _frames(1)
		var level: Level = game.level
		for p in level.solution_presses():
			var si: int = p[0]
			var stamp: StampDef = level.stamps[si]
			var btn: StampButton = game._buttons[si]
			var turns := 0
			while stamp.cells(p[1], btn.rot) != stamp.cells(p[1], p[2]) and turns < 4:
				game._on_rotate(si)
				turns += 1
			game._on_stamp_tapped(si)
			if stamp.spot_count() > 1:
				game._on_spot_tapped(p[1])
		await _frames(1)
		if not game.won:
			failures.append("%s: playing the solution did not win" % level.id)
		elif game.stars() != 3:
			failures.append("%s: a clean solve should give 3 stars, gave %d" % [level.id, game.stars()])
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
