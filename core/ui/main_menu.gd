extends Screen
## Title screen. The logo is itself a tiny level that stamps itself in.

const LOGO := {
	"id": "logo",
	"palette": "garden",
	"stamps": [
		{"shape": "square", "size": 7, "color": 4, "placements": [{"x": 2, "y": 3, "rot": 0}]},
		{"shape": "sun", "size": 8, "color": 3, "placements": [{"x": 6, "y": 5, "rot": 0}]},
		{"shape": "leaf", "size": 6, "color": 1, "placements": [{"x": 1, "y": 9, "rot": 0}]},
		{"shape": "star", "size": 6, "color": 8, "placements": [{"x": 9, "y": 1, "rot": 0}]},
	],
	"solution": [[0, 0], [1, 0], [2, 0], [3, 0]],
}

var _logo: CanvasView
var _logo_level: Level
var _logo_board := BoardState.new()
var _logo_presses: Array = []


func build() -> void:
	body.add_theme_constant_override("separation", 16)
	var top_space := Control.new()
	top_space.custom_minimum_size = Vector2(0, 20)
	body.add_child(top_space)

	_logo_level = Level.from_dict(LOGO)
	_logo = CanvasView.new()
	_logo.custom_minimum_size = Vector2(300, 300)
	_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.pivot_offset = Vector2(150, 150)
	_logo.rotation = deg_to_rad(-3)
	_logo.show_level(_logo_level, _logo_presses, _logo_board)
	body.add_child(_logo)

	body.add_child(make_label("Stamp Order", "TitleLabel"))
	body.add_child(make_label("Press the stamps in the right order\nto recreate each picture.", "SubtleLabel"))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)

	var idx := Levels.continue_index()
	var play := make_button("Play", func() -> void: Router.goto("game", {"index": idx}), "AccentButton")
	play.custom_minimum_size = Vector2(0, 120)
	body.add_child(play)
	if Levels.count() > 0:
		var lvl := Levels.get_level(idx)
		body.add_child(make_label("Next up: level %s" % Levels.label(lvl), "SubtleLabel"))
	body.add_child(make_button("Levels", func() -> void: Router.goto("levels")))
	body.add_child(make_button("Gallery", func() -> void: Router.goto("gallery")))
	body.add_child(make_button("Settings", func() -> void: Router.goto("settings")))

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	var star := StarsView.new(1, Vector2(40, 40))
	star.slots = 1
	footer.add_child(star)
	footer.add_child(make_label("%d / %d" % [Save.total_stars(), Levels.count() * 3], "SubtleLabel"))
	body.add_child(footer)

	_stamp_logo()
	print("STAMP_ORDER_READY")


func _stamp_logo() -> void:
	var tw := create_tween()
	tw.tween_interval(0.3)
	for p in _logo_level.solution_presses():
		tw.tween_callback(func() -> void:
			_logo_presses.append(p)
			_logo_board.press(_logo_level.stamps[p[0]], p[1], p[2])
			_logo.animate_press()
			Audio.play_press())
		tw.tween_interval(0.28)


func on_back() -> void:
	get_tree().quit()
