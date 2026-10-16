extends Screen
## The gallery wall: every finished picture, framed, one wall per world.


func build() -> void:
	body.add_child(make_top_bar("Gallery"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var walls := VBoxContainer.new()
	walls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	walls.add_theme_constant_override("separation", 26)
	scroll.add_child(walls)
	var cb := bool(Save.get_setting("colorblind"))
	for w in Levels.worlds:
		var done := 0
		for level: Level in w["levels"]:
			if Save.is_completed(level.id):
				done += 1
		walls.add_child(make_label("%s  ·  %d / %d" % [w["name"], done, w["levels"].size()], "", HORIZONTAL_ALIGNMENT_LEFT))
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		walls.add_child(grid)
		for level: Level in w["levels"]:
			grid.add_child(_frame(level, cb))


func _frame(level: Level, colorblind: bool) -> Control:
	var frame := PanelContainer.new()
	var done := Save.is_completed(level.id)
	var sb := UITheme.box(UITheme.FRAME if done else UITheme.LINE, 6, done)
	sb.set_content_margin_all(7)
	if level.picture and done:
		sb.bg_color = UITheme.GOLD.darkened(0.15)
	frame.add_theme_stylebox_override("panel", sb)
	# Let touch drags reach the ScrollContainer.
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	if done:
		var pic := CanvasView.new()
		pic.thumbnail = true
		pic.colorblind = colorblind
		pic.custom_minimum_size = Vector2(110, 110)
		pic.show_target(level)
		frame.add_child(pic)
	else:
		var blank := ColorRect.new()
		blank.color = Color("ebe4d8")
		blank.custom_minimum_size = Vector2(110, 110)
		blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(blank)
	return frame
