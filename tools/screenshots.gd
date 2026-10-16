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
	router.goto("game", {"index": 6})
	await _shot(out_dir, "03_game")
	var game: Node = current_scene
	var plan: Array = game.level.solution_presses()
	game._on_stamp_tapped(plan[0][0])
	game._on_stamp_tapped(plan[1][0])
	await _shot(out_dir, "04_game_two_pressed", 30)
	game._on_hint()
	await _shot(out_dir, "05_hint", 20)
	game.start_level(21, false)
	var two := -1
	for i in game.level.stamps.size():
		if game.level.stamps[i].spot_count() > 1:
			two = i
	game._on_stamp_tapped(two)
	await _shot(out_dir, "06_two_spots", 20)
	game.start_level(42, false)
	save.set_setting("colorblind", true)
	await _shot(out_dir, "07_rotation_colorblind", 20)
	save.set_setting("colorblind", false)
	game.start_level(9, false)
	for p in game.level.solution_presses():
		game._on_stamp_tapped(p[0])
	await _shot(out_dir, "08_win", 120)
	router.goto("gallery")
	await _shot(out_dir, "09_gallery")
	router.goto("settings")
	await _shot(out_dir, "10_settings")
	save.reset_progress()
	quit()
