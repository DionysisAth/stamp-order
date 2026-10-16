extends Screen
## The play screen: turns taps into commands on the undo stack, drives the
## views from the board state and runs the win flow.

var level: Level
var board := BoardState.new()
## Presses so far, bottom-up: [stamp_index, spot, rot]. Shared with the
## canvas view and the press commands, so it is only ever changed in place.
var presses: Array = []
var stack := UndoStack.new()
var undo_count := 0
var restarts := 0
var hints_used := 0
var won := false
var selected := -1

var _title: Label
var _level_name: Label
var _tip: Label
var _message: Label
var _progress: Label
var _target: CanvasView
var _canvas: CanvasView
var _tray: GridContainer
var _buttons: Array[StampButton] = []
var _undo_btn: IconButton
var _restart_btn: IconButton
var _hint_btn: IconButton
var _win: WinPanel
var _started_at := 0
var _quit_logged := false


func build() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	bar.add_child(IconButton.create("back", on_back))
	_title = make_label("", "HeaderLabel")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_title)
	_hint_btn = IconButton.create("hint", _on_hint)
	_undo_btn = IconButton.create("undo", _on_undo)
	_restart_btn = IconButton.create("restart", _on_restart)
	for b in [_hint_btn, _undo_btn, _restart_btn]:
		bar.add_child(b)
	body.add_child(bar)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	body.add_child(header)
	var target_card := PanelContainer.new()
	var tsb := UITheme.box(UITheme.CARD, 22, true)
	tsb.set_content_margin_all(12)
	target_card.add_theme_stylebox_override("panel", tsb)
	header.add_child(target_card)
	var tbox := VBoxContainer.new()
	tbox.add_theme_constant_override("separation", 6)
	target_card.add_child(tbox)
	tbox.add_child(make_label("TARGET", "SubtleLabel"))
	_target = CanvasView.new()
	_target.thumbnail = true
	_target.custom_minimum_size = Vector2(236, 236)
	tbox.add_child(_target)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 8)
	header.add_child(info)
	_level_name = make_label("", "", HORIZONTAL_ALIGNMENT_LEFT)
	_level_name.add_theme_font_size_override("font_size", 34)
	info.add_child(_level_name)
	_tip = make_label("", "SubtleLabel", HORIZONTAL_ALIGNMENT_LEFT)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(_tip)
	_message = make_label("", "", HORIZONTAL_ALIGNMENT_LEFT)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_font_size_override("font_size", 26)
	_message.add_theme_color_override("font_color", UITheme.ACCENT_DARK)
	info.add_child(_message)
	_progress = make_label("", "SubtleLabel", HORIZONTAL_ALIGNMENT_LEFT)
	info.add_child(_progress)

	_canvas = CanvasView.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size = Vector2(0, 360)
	_canvas.spot_tapped.connect(_on_spot_tapped)
	_canvas.canvas_tapped.connect(_deselect)
	body.add_child(_canvas)

	var tray_center := CenterContainer.new()
	body.add_child(tray_center)
	_tray = GridContainer.new()
	_tray.add_theme_constant_override("h_separation", 14)
	_tray.add_theme_constant_override("v_separation", 14)
	tray_center.add_child(_tray)

	_win = WinPanel.new()
	add_child(_win)
	_win.next_pressed.connect(_on_next)
	_win.replay_pressed.connect(func() -> void: start_level(level.global_index, true))
	_win.levels_pressed.connect(func() -> void: Router.goto("levels", {"world": level.world}))

	Save.settings_changed.connect(func(_k: String, _v: Variant) -> void: _refresh())
	start_level(int(Router.params.get("index", Levels.current_index)), false)


func start_level(index: int, slide: bool) -> void:
	level = Levels.get_level(index)
	Levels.current_index = level.global_index
	board.clear()
	presses.clear()
	stack.clear()
	undo_count = 0
	restarts = 0
	hints_used = 0
	won = false
	selected = -1
	_quit_logged = false
	_started_at = Time.get_ticks_msec()
	_win.hide_panel()

	var world := Levels.world_info(level.world)
	_title.text = "Level %s" % Levels.label(level)
	_level_name.text = level.title if level.title != "" else str(world["name"])
	_tip.text = level.tip
	_message.text = ""
	_canvas.show_level(level, presses, board)
	_target.show_target(level)

	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	var n := level.stamps.size()
	_tray.columns = n if n <= 5 else ceili(n / 2.0)
	for i in n:
		var b := StampButton.new(i, level.stamps[i], level.palette)
		b.tapped.connect(_on_stamp_tapped)
		b.rotate_requested.connect(_on_rotate)
		_tray.add_child(b)
		_buttons.append(b)
	_refresh()
	Analytics.event("level_start", {"level": level.id, "index": level.global_index})
	if slide:
		_canvas.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(_canvas, "modulate:a", 1.0, 0.25)
		_canvas.position.x += 120
		tw.tween_property(_canvas, "position:x", _canvas.position.x - 120, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func is_used(stamp_index: int) -> bool:
	for p in presses:
		if p[0] == stamp_index:
			return true
	return false


func used_stamps() -> Array:
	var out := []
	for p in presses:
		out.append(p[0])
	return out


## Presses a stamp at a spot with the tray's current rotation.
func press(stamp_index: int, spot: int, rot: int) -> void:
	if won or is_used(stamp_index):
		return
	stack.push(PressCommand.new(board, presses, level.stamps[stamp_index], stamp_index, spot, rot))
	_deselect()
	_clear_hint()
	_message.text = ""
	_canvas.queue_redraw()
	_canvas.animate_press()
	Audio.play_press()
	Haptics.tap(20)
	_refresh()
	_check_done()


func stars() -> int:
	if hints_used > 0:
		return 1
	if undo_count > 0 or restarts > 0:
		return 2
	return 3


func _on_stamp_tapped(i: int) -> void:
	if won:
		return
	if is_used(i):
		_buttons[i].bump()
		_message.text = "Already pressed. Undo to lift it again."
		return
	var s := level.stamps[i]
	if s.spot_count() == 1:
		press(i, 0, _buttons[i].rot)
		return
	if selected == i:
		_deselect()
		return
	_deselect()
	selected = i
	_buttons[i].selected = true
	_canvas.set_ghost(i, _buttons[i].rot)
	_message.text = "Tap one of the marked spots on the paper."


func _on_spot_tapped(spot: int) -> void:
	if selected >= 0:
		press(selected, spot, _buttons[selected].rot)


func _on_rotate(i: int) -> void:
	if won or is_used(i):
		return
	var b := _buttons[i]
	b.set_rot(b.rot + 90)
	Audio.play_rotate()
	Haptics.tap(10)
	if selected == i:
		_canvas.set_ghost(i, b.rot)
	if not _canvas.hint_pose.is_empty() and _canvas.hint_pose[0] == i:
		_message.text = "That's the way. Now press it." if _rot_matches_hint(i) else "Keep turning it."


func _rot_matches_hint(i: int) -> bool:
	var h: Array = _canvas.hint_pose
	var s := level.stamps[i]
	return s.cells(h[1], _buttons[i].rot) == s.cells(h[1], h[2])


func _deselect() -> void:
	if selected >= 0 and selected < _buttons.size():
		_buttons[selected].selected = false
	selected = -1
	_canvas.set_ghost(-1, 0)


func _clear_hint() -> void:
	for b in _buttons:
		b.hinted = false
	_canvas.set_hint([])


func _on_undo() -> void:
	if won or not stack.undo():
		return
	undo_count += 1
	_deselect()
	_clear_hint()
	_message.text = ""
	Audio.play_undo()
	Haptics.tap(10)
	_canvas.queue_redraw()
	_refresh()


func _on_restart() -> void:
	if won or presses.is_empty():
		return
	restarts += 1
	board.clear()
	presses.clear()
	stack.clear()
	_deselect()
	_clear_hint()
	_message.text = ""
	for b in _buttons:
		b.set_rot(b.stamp.initial_rot(), false)
	Audio.play_undo()
	_canvas.queue_redraw()
	_refresh()


func _on_hint() -> void:
	if won:
		return
	_deselect()
	_clear_hint()
	hints_used += 1
	Save.record_hint()
	var h: Variant = Solver.hint(level, board, used_stamps())
	Analytics.event("hint_used", {"level": level.id, "presses": presses.size(), "ok": h != null})
	if h == null:
		_message.text = "Something is on top that shouldn't be. Undo the last stamp."
		var tw := create_tween()
		_undo_btn.pivot_offset = _undo_btn.size * 0.5
		tw.tween_property(_undo_btn, "scale", Vector2(1.2, 1.2), 0.15)
		tw.tween_property(_undo_btn, "scale", Vector2.ONE, 0.15)
		return
	var i: int = h[0]
	_buttons[i].hinted = true
	_canvas.set_hint(h)
	var s := level.stamps[i]
	if s.rotatable and not _rot_matches_hint(i):
		_message.text = "Press this one next, but turn it first: tap and hold it."
	elif s.spot_count() > 1:
		_message.text = "Press this one next, on the glowing spot."
	else:
		_message.text = "Press this one next."


func _check_done() -> void:
	if presses.size() < level.stamps.size():
		return
	if board.matches(level.target()):
		_on_win()
	else:
		Audio.play_error()
		_canvas.shake()
		_message.text = "Not quite. Compare with the target, then undo."


func _on_win() -> void:
	won = true
	var s := stars()
	Save.record_win(level.id, level.global_index, s)
	var seconds := (Time.get_ticks_msec() - _started_at) / 1000.0
	Analytics.event("level_complete", {"level": level.id, "stars": s, "undos": undo_count, "restarts": restarts, "hints": hints_used, "seconds": seconds})
	Analytics.event("undo_count", {"level": level.id, "count": undo_count, "completed": true})
	Audio.play_win()
	Haptics.success()
	_refresh()
	# The paper lifts off the desk before it is framed.
	_canvas.pivot_offset = _canvas.size * 0.5
	var tw := create_tween()
	tw.tween_property(_canvas, "scale", Vector2(1.05, 1.05), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_canvas, "position:y", _canvas.position.y - 24, 0.18)
	tw.tween_interval(0.25)
	tw.tween_callback(func() -> void:
		_canvas.scale = Vector2.ONE
		_canvas.position.y += 24
		_win.show_result(level, s, Levels.next_index(level.global_index) >= 0, _colorblind()))


func _on_next() -> void:
	var nxt := Levels.next_index(level.global_index)
	if nxt < 0:
		Router.goto("gallery")
	else:
		start_level(nxt, true)


func _colorblind() -> bool:
	return bool(Save.get_setting("colorblind"))


func _refresh() -> void:
	var cb := _colorblind()
	_canvas.colorblind = cb
	_target.colorblind = cb
	_canvas.queue_redraw()
	_target.queue_redraw()
	for b in _buttons:
		b.used = is_used(b.index)
		b.colorblind = cb
		b.queue_redraw()
	_undo_btn.disabled = won or not stack.can_undo()
	_restart_btn.disabled = won or presses.is_empty()
	_hint_btn.disabled = won
	_progress.text = "%d of %d stamps pressed" % [presses.size(), level.stamps.size()]


func _log_quit(reason: String) -> void:
	if won or _quit_logged or level == null:
		return
	_quit_logged = true
	var seconds := (Time.get_ticks_msec() - _started_at) / 1000.0
	Analytics.event("quit_mid_level", {"level": level.id, "presses": presses.size(), "undos": undo_count, "hints": hints_used, "seconds": seconds, "reason": reason})
	Analytics.event("undo_count", {"level": level.id, "count": undo_count, "completed": false})


func on_back() -> void:
	if selected >= 0:
		_deselect()
		return
	_log_quit("back")
	Router.goto("levels", {"world": level.world})


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			_log_quit("app_closed")
		NOTIFICATION_APPLICATION_RESUMED:
			_quit_logged = false
