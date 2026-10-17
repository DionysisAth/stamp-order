extends Screen
## World tabs and a grid of colourful level tiles with their stars. Locked
## levels show a padlock; the next level to play gently pulses.

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
		b.custom_minimum_size = Vector2(0, 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 28)
		var n: int = w["number"]
		b.pressed.connect(func() -> void:
			Audio.play_click()
			_show_world(n))
		tabs.add_child(b)
		_tabs.append(b)

	_twist = make_label("", "OnColorLabel")
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


func background_key() -> String:
	return "garden"


func _show_world(n: int) -> void:
	world = n
	background.colors = UITheme.world_gradient(n)
	for i in _tabs.size():
		_style_tab(_tabs[i], i + 1, i + 1 == n)
	for c in _grid.get_children():
		c.queue_free()
	if Levels.worlds.is_empty():
		return
	var info := Levels.world_info(n)
	_twist.text = str(info["twist"])
	var next := Levels.continue_index()
	for level: Level in info["levels"]:
		_grid.add_child(_make_tile(level, level.global_index == next))


func _style_tab(b: Button, n: int, active: bool) -> void:
	var face := UITheme.world_color(n) if active else UITheme.CARD
	var edge := face.darkened(0.25) if active else UITheme.CARD_EDGE
	b.add_theme_stylebox_override("normal", UITheme.candy(face, edge, 26, 7))
	b.add_theme_stylebox_override("hover", UITheme.candy(face.lightened(0.05), edge, 26, 7))
	b.add_theme_stylebox_override("pressed", UITheme.candy(face, edge, 26, 7, true))
	var text := Color.WHITE if active else UITheme.INK
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, text)


func _make_tile(level: Level, is_next: bool) -> Control:
	var unlocked := Save.is_unlocked(level.global_index)
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(150, 156)
	tile.disabled = not unlocked
	tile.focus_mode = Control.FOCUS_NONE
	var face := UITheme.world_color(level.world)
	if level.picture:
		face = UITheme.SUN
	var edge := face.darkened(0.28)
	if unlocked:
		tile.add_theme_stylebox_override("normal", UITheme.candy(face, edge, 30, 9))
		tile.add_theme_stylebox_override("hover", UITheme.candy(face.lightened(0.06), edge, 30, 9))
		tile.add_theme_stylebox_override("pressed", UITheme.candy(face, edge, 30, 9, true))
	else:
		tile.add_theme_stylebox_override("disabled", UITheme.box(Color(1, 1, 1, 0.28), 30))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_bottom = -8
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(box)
	if unlocked:
		var num := Label.new()
		num.text = str(level.number)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.label_settings = UITheme.label_settings(56, Color.WHITE, 12, edge)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(num)
		var stars := StarsView.new(Save.stars_for(level.id), Vector2(118, 36))
		stars.empty_color = Color(1, 1, 1, 0.4)
		stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(stars)
	else:
		var lock := Padlock.new()
		lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(lock)
	if is_next and unlocked:
		tile.resized.connect(func() -> void: tile.pivot_offset = tile.size * 0.5)
		var tw := tile.create_tween().set_loops()
		tw.tween_property(tile, "scale", Vector2(1.07, 1.07), 0.55).set_trans(Tween.TRANS_SINE)
		tw.tween_property(tile, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)
	var idx := level.global_index
	tile.pressed.connect(func() -> void:
		Audio.play_click()
		Router.goto("game", {"index": idx}))
	return tile


class Padlock extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(56, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var col := Color(1, 1, 1, 0.85)
		var w := size.x
		draw_arc(Vector2(w * 0.5, size.y * 0.42), w * 0.26, PI, TAU, 16, col, w * 0.11, true)
		var body := StyleBoxFlat.new()
		body.bg_color = col
		body.set_corner_radius_all(int(w * 0.16))
		body.anti_aliasing = true
		draw_style_box(body, Rect2(Vector2(w * 0.12, size.y * 0.42), Vector2(w * 0.76, size.y * 0.5)))
		draw_circle(Vector2(w * 0.5, size.y * 0.64), w * 0.08, Color(0.17, 0.14, 0.28, 0.35), true, -1.0, true)
