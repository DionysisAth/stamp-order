extends SceneTree
## Captures screenshots of the main screens (needs a real renderer, e.g.
## under xvfb-run):
##   godot --resolution 720x1280 --script res://tools/screenshots.gd -- <out_dir>


func _initialize() -> void:
	_run.call_deferred()


func _shot(out_dir: String, name: String, frames: int = 40) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://build/screenshots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var router: Node = root.get_node("Router")
	var save: Node = root.get_node("Save")
	save.path = "user://screenshot_save.json"
	save.reset_progress()
	for i in 13:
		save.record_win("w1_%02d" % (i + 1), i, 3 - i % 3)
	router.goto("menu")
	await _shot(out_dir, "01_menu", 90)
	router.goto("levels", {"world": 1})
	await _shot(out_dir, "02_levels")
	# Plan mode: a half-built plan with numbered outlines.
	router.goto("game", {"index": 6})
	await _shot(out_dir, "03_plan", 30)
	var game: Node = current_scene
	var plan: Array = game.level.solution_presses()
	game._on_stamp_tapped(plan[0][0])
	game._on_stamp_tapped(plan[1][0])
	await _shot(out_dir, "04_plan_two_queued", 30)
	# A wrong plan, stamped: the bad slot is marked.
	game._on_restart()
	for k in range(plan.size() - 1, -1, -1):
		game._on_stamp_tapped(plan[k][0])
	game.stamp_interval = 0.0
	game._on_stamp_go()
	await _shot(out_dir, "05_failed_run", 30)
	game._on_restart()
	game._on_hint()
	await _shot(out_dir, "06_hint_look_here", 20)
	game._on_hint()
	await _shot(out_dir, "07_hint_stamp", 20)
	# The eraser intro (level 21) and a spare-stamp level (10).
	game.start_level(20, false)
	await _shot(out_dir, "08_eraser", 20)
	game.start_level(9, false)
	await _shot(out_dir, "09_spare", 20)
	# Win replay with numbered layers.
	game.start_level(14, false)
	for p in game.level.solution_presses():
		game._on_stamp_tapped(p[0])
	game._on_stamp_go()
	await _shot(out_dir, "10_win", 150)
	router.goto("levels", {"world": 4})
	await _shot(out_dir, "11_levels_w4")
	# Prototypes.
	router.goto("prototypes")
	await _shot(out_dir, "20_modes")
	router.goto("proto_free", {"index": 3})
	await _shot(out_dir, "21_free_start", 30)
	var fg: Node = current_scene
	var sol: Array = fg.level.solution
	fg.press(sol[0][0], Vector2i(sol[0][1], sol[0][2]))
	fg._on_hover(sol[1][0], Vector2i(sol[1][1], sol[1][2]))
	await _shot(out_dir, "22_free_ghost", 30)
	fg.start_level(9)
	await _shot(out_dir, "23_free_10", 30)
	router.goto("proto_stack", {"index": 4})
	await _shot(out_dir, "24_stack_start", 30)
	var sg: Node = current_scene
	sg.flight_seconds = 0.0
	for k in 4:
		sg.pick(sg.level.solution[k])
	await _shot(out_dir, "25_stack_picks", 20)
	save.reset_progress()
	quit()
