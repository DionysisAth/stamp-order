extends Screen
## World tabs and a grid of levels with their stars. Locked levels are greyed.

var world := 1
var _grid: GridContainer
var _tabs: Array[Button] = []
var _twist: Label


func build() -> void:
	world = int(Router.params.get("world", Levels.get_level(Levels.continue_index()).world if Levels.count() > 0 else 1))
	body.add_child(make_top_bar("Levels"))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	body.add_child(tabs)
	for w in Levels.worlds:
		var b := Button.new()
		b.text = w["name"]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 84)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 26)
		var n: int = w["number"]
		b.pressed.connect(func() -> void:
			Audio.play_click()
			_show_world(n))
		tabs.add_child(b)
		_tabs.append(b)

	_twist = make_label("", "SubtleLabel")
	body.add_child(_twist)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 18)
	center.add_child(_grid)
	_show_world(world)


func _show_world(n: int) -> void:
	world = n
	for i in _tabs.size():
		_tabs[i].button_pressed = (i + 1 == n)
	for c in _grid.get_children():
		c.queue_free()
	if Levels.worlds.is_empty():
		return
	var info := Levels.world_info(n)
	_twist.text = str(info["twist"])
	for level: Level in info["levels"]:
		_grid.add_child(_make_tile(level))


func _make_tile(level: Level) -> Control:
	var unlocked := Save.is_unlocked(level.global_index)
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(150, 150)
	tile.disabled = not unlocked
	tile.focus_mode = Control.FOCUS_NONE
	if level.picture:
		for state in ["normal", "hover", "pressed"]:
			tile.add_theme_stylebox_override(state, UITheme.box(UITheme.CARD, 22, true, UITheme.GOLD))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(box)
	var num := Label.new()
	num.text = str(level.number) if unlocked else "·"
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 44)
	if not unlocked:
		num.add_theme_color_override("font_color", Color(UITheme.INK, 0.3))
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(num)
	if unlocked:
		var stars := StarsView.new(Save.stars_for(level.id), Vector2(110, 34))
		stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(stars)
	var idx := level.global_index
	tile.pressed.connect(func() -> void:
		Audio.play_click()
		Router.goto("game", {"index": idx}))
	return tile
