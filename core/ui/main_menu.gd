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


const TITLE_COLORS := ["ff3d7f", "ffc61a", "2ee6a6", "4dabff", "b14dff", "ff8a00"]


func build() -> void:
	body.add_theme_constant_override("separation", 14)
	var top_space := Control.new()
	top_space.custom_minimum_size = Vector2(0, 8)
	body.add_child(top_space)

	_logo_level = Level.from_dict(LOGO)
	_logo = CanvasView.new()
	_logo.custom_minimum_size = Vector2(280, 280)
	_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.pivot_offset = Vector2(140, 140)
	_logo.rotation = deg_to_rad(-4)
	_logo.show_level(_logo_level, _logo_presses, _logo_board)
	body.add_child(_logo)

	body.add_child(_title_word("STAMP", 0, 112))
	body.add_child(_title_word("ORDER", 3, 112))
	body.add_child(make_label("Press the stamps in the right order\nto recreate each picture.", "OnColorLabel"))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)

	var idx := Levels.continue_index()
	var play := make_button("PLAY", func() -> void: Router.goto("game", {"index": idx}), "SunButton")
	play.custom_minimum_size = Vector2(0, 132)
	body.add_child(play)
	_breathe(play)
	if Levels.count() > 0:
		var lvl := Levels.get_level(idx)
		body.add_child(make_label("Next up: level %s" % Levels.label(lvl), "OnColorLabel"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	for spec in [["Levels", "levels"], ["Gallery", "gallery"]]:
		var target: String = spec[1]
		var b := make_button(spec[0], func() -> void: Router.goto(target))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 14)
	body.add_child(row2)
	var modes := make_button("New modes", func() -> void: Router.goto("prototypes"), "AccentButton")
	modes.add_theme_font_size_override("font_size", 32)
	modes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(modes)
	var settings := make_button("Settings", func() -> void: Router.goto("settings"))
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(settings)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 8)
	var star := StarsView.new(1, Vector2(48, 48))
	star.slots = 1
	footer.add_child(star)
	var count := Label.new()
	count.text = "%d / %d" % [Save.total_stars(), Levels.count() * 3]
	count.label_settings = UITheme.label_settings(34, Color.WHITE, 0, UITheme.INK, true)
	footer.add_child(count)
	body.add_child(footer)

	_stamp_logo()
	print("STAMP_ORDER_READY")


## A word of chunky letters, each in its own ink colour with a white rim,
## tilted a little like hand-pressed stamps. They pop in one by one.
func _title_word(word: String, color_offset: int, font_size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	row.custom_minimum_size = Vector2(0, font_size * 0.95)
	for i in word.length():
		var l := Label.new()
		l.text = word[i]
		l.label_settings = UITheme.label_settings(font_size, Color(TITLE_COLORS[(i + color_offset) % TITLE_COLORS.size()]), 22, Color.WHITE, true)
		l.label_settings.shadow_size = 2
		l.label_settings.shadow_offset = Vector2(0, 8)
		l.label_settings.shadow_color = Color(0.15, 0.04, 0.4, 0.35)
		l.custom_minimum_size = Vector2(font_size * 0.66, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(l)
		var tilt := deg_to_rad([-6.0, 4.0, -3.0, 6.0, -4.0][(i + color_offset) % 5])
		l.rotation = tilt
		l.scale = Vector2.ZERO
		l.resized.connect(func() -> void: l.pivot_offset = l.size * 0.5)
		var tw := create_tween()
		tw.tween_interval(0.25 + (i + color_offset) * 0.07)
		tw.tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return row


## Gently pulses a control to draw the eye.
func _breathe(c: Control) -> void:
	c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)
	var tw := create_tween().set_loops()
	tw.tween_property(c, "scale", Vector2(1.03, 1.03), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)


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
