extends Screen
## The play screen. Two ways to play:
##  - live (tutorial levels): every tap presses a stamp; presses go on the
##    undo stack.
##  - plan (from level 5 on): the player lines stamps up in a plan, bottom
##    first, then hits STAMP! and watches the plan play out. A failed run
##    marks the first stamp that broke the picture. Editing the plan is free;
##    only failed runs and hints cost stars.

## Seconds between stamps when a plan plays out (0 = instant, for tests).
var stamp_interval := 0.38

var level: Level
var board := BoardState.new()
## Presses on the canvas, bottom-up: [stamp_index, spot, rot]. Shared with
## the canvas view and the press commands, so it is only changed in place.
var presses: Array = []
## Plan mode: the queued presses, bottom-up.
var plan: Array = []
var stack := UndoStack.new()
var undo_count := 0
var restarts := 0
var hints_used := 0
## Plan mode: STAMP! runs that did not match the target.
var failed_runs := 0
var won := false
var selected := -1
var busy := false

var _title: Label
var _level_name: Label
var _tip: Label
var _message: Label
var _progress: ProgressPips
var _seal: PerfectSeal
var _target_pill: Label
var _target: CanvasView
var _canvas: CanvasView
var _tray: GridContainer
var _plan_row: HBoxContainer
var _strip: PlanStrip
var _stamp_btn: Button
var _buttons: Array[StampButton] = []
var _undo_btn: IconButton
var _restart_btn: IconButton
var _hint_btn: IconButton
var _win: WinPanel
var _started_at := 0
var _quit_logged := false
var _showing_run := false
var _hint_step := 0
var _hint_stamp := -1


func background_key() -> String:
	return "garden"


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

	var card := PanelContainer.new()
	var csb := UITheme.box(UITheme.CARD, 30, true)
	csb.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", csb)
	body.add_child(card)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	card.add_child(header)
	var tbox := VBoxContainer.new()
	tbox.add_theme_constant_override("separation", 8)
	header.add_child(tbox)
	_target_pill = Label.new()
	_target_pill.text = "TARGET"
	_target_pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_pill.label_settings = UITheme.label_settings(22, Color.WHITE)
	tbox.add_child(_target_pill)
	_target = CanvasView.new()
	_target.thumbnail = true
	_target.custom_minimum_size = Vector2(204, 204)
	tbox.add_child(_target)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	header.add_child(info)
	_level_name = Label.new()
	_level_name.label_settings = UITheme.label_settings(34, UITheme.INK)
	_level_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_level_name)
	_tip = make_label("", "SubtleLabel", HORIZONTAL_ALIGNMENT_LEFT)
	_tip.add_theme_font_size_override("font_size", 23)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(_tip)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.label_settings = UITheme.label_settings(24, UITheme.ACCENT)
	info.add_child(_message)
	var status := HBoxContainer.new()
	info.add_child(status)
	_progress = ProgressPips.new()
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(_progress)
	_seal = PerfectSeal.new()
	status.add_child(_seal)

	_canvas = CanvasView.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size = Vector2(0, 330)
	_canvas.spot_tapped.connect(_on_spot_tapped)
	_canvas.canvas_tapped.connect(_deselect)
	body.add_child(_canvas)

	_plan_row = HBoxContainer.new()
	_plan_row.add_theme_constant_override("separation", 12)
	body.add_child(_plan_row)
	_strip = PlanStrip.new()
	_strip.slot_tapped.connect(_remove_from_plan)
	_plan_row.add_child(_strip)
	_stamp_btn = make_button("STAMP!", _on_stamp_go, "SunButton")
	_stamp_btn.add_theme_font_size_override("font_size", 38)
	_stamp_btn.custom_minimum_size = Vector2(196, 104)
	_plan_row.add_child(_stamp_btn)

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


func is_plan_mode() -> bool:
	return level.mode == "plan"


func start_level(index: int, slide: bool) -> void:
	level = Levels.get_level(index)
	Levels.current_index = level.global_index
	board.clear()
	presses.clear()
	plan.clear()
	stack.clear()
	undo_count = 0
	restarts = 0
	hints_used = 0
	failed_runs = 0
	won = false
	busy = false
	selected = -1
	_showing_run = false
	_hint_step = 0
	_hint_stamp = -1
	_quit_logged = false
	_started_at = Time.get_ticks_msec()
	_win.hide_panel()
	_seal.reset()

	var world := Levels.world_info(level.world)
	var wc := UITheme.world_color(level.world)
	background.colors = UITheme.world_gradient(level.world)
	_progress.color = wc
	var pill := UITheme.box(wc, 18)
	pill.content_margin_top = 4
	pill.content_margin_bottom = 4
	_target_pill.add_theme_stylebox_override("normal", pill)
	_title.text = "Level %s" % Levels.label(level)
	_level_name.text = level.title if level.title != "" else str(world["name"])
	_tip.text = level.tip
	_message.text = ""
	_canvas.show_level(level, presses, board)
	_target.show_target(level)
	_plan_row.visible = is_plan_mode()
	_strip.level = level
	_strip.entries = plan
	_strip.slots = level.solution.size()
	_strip.bad_index = -1
	_strip.active_index = -1

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
	Analytics.event("level_start", {"level": level.id, "index": level.global_index, "mode": level.mode})
	if slide:
		_canvas.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(_canvas, "modulate:a", 1.0, 0.25)
		_canvas.position.x += 120
		tw.tween_property(_canvas, "position:x", _canvas.position.x - 120, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Stamps already pressed (live) or already in the plan (plan mode).
func is_used(stamp_index: int) -> bool:
	for p in (plan if is_plan_mode() else presses):
		if p[0] == stamp_index:
			return true
	return false


func used_stamps() -> Array:
	var out := []
	for p in presses:
		out.append(p[0])
	return out


## Live mode: presses a stamp at a spot with the tray's current rotation.
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
	_check_live_done()


func stars() -> int:
	if hints_used > 0:
		return 1
	if undo_count > 0 or restarts > 0 or failed_runs > 0:
		return 2
	return 3


func _on_stamp_tapped(i: int) -> void:
	if won or busy:
		return
	if is_used(i):
		if is_plan_mode():
			_remove_from_plan(_plan_index_of(i))
		else:
			_buttons[i].bump()
			_message.text = "Already pressed. Undo to lift it again."
		return
	if is_plan_mode() and plan.size() >= _strip.slots:
		_buttons[i].bump()
		_message.text = "Your plan is full. Tap a slot to take a stamp out."
		return
	var s := level.stamps[i]
	if s.spot_count() == 1:
		_place(i, 0, _buttons[i].rot)
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
		_place(selected, spot, _buttons[selected].rot)


func _place(i: int, spot: int, rot: int) -> void:
	if is_plan_mode():
		_add_to_plan(i, spot, rot)
	else:
		press(i, spot, rot)


func _plan_index_of(stamp_index: int) -> int:
	for k in plan.size():
		if plan[k][0] == stamp_index:
			return k
	return -1


func _add_to_plan(i: int, spot: int, rot: int) -> void:
	plan.append([i, spot, rot])
	_buttons[i].bump()
	Audio.play_click()
	Haptics.tap(10)
	_plan_changed()


func _remove_from_plan(k: int) -> void:
	if busy or won or k < 0 or k >= plan.size():
		return
	plan.remove_at(k)
	Audio.play_undo()
	_plan_changed()


## Any plan edit clears the last run from the paper and resets the hints.
func _plan_changed() -> void:
	if _showing_run:
		_showing_run = false
		board.clear()
		presses.clear()
	_strip.bad_index = -1
	_hint_step = 0
	_hint_stamp = -1
	_deselect()
	_clear_hint()
	_message.text = ""
	_refresh()


func _on_rotate(i: int) -> void:
	if won or busy or is_used(i):
		return
	var b := _buttons[i]
	b.set_rot(b.rot + 90)
	Audio.play_rotate()
	Haptics.tap(10)
	if selected == i:
		_canvas.set_ghost(i, b.rot)
	if not _canvas.hint_pose.is_empty() and _canvas.hint_pose[0] == i:
		_message.text = "That's the way. Now use it." if _rot_matches_hint(i) else "Keep turning it."


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
	_target.set_clue([])


func _on_undo() -> void:
	if won or busy:
		return
	if is_plan_mode():
		_remove_from_plan(plan.size() - 1)
		return
	if not stack.undo():
		return
	undo_count += 1
	_seal.crack()
	_deselect()
	_clear_hint()
	_message.text = ""
	Audio.play_undo()
	Haptics.tap(10)
	_canvas.queue_redraw()
	_refresh()


func _on_restart() -> void:
	if won or busy:
		return
	if is_plan_mode():
		if plan.is_empty() and not _showing_run:
			return
		plan.clear()
		Audio.play_undo()
		_plan_changed()
		return
	if presses.is_empty():
		return
	restarts += 1
	_seal.crack()
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


# --- plan mode: STAMP! ------------------------------------------------------

func _on_stamp_go() -> void:
	if won or busy or plan.is_empty():
		return
	busy = true
	_deselect()
	_clear_hint()
	_message.text = ""
	_strip.bad_index = -1
	board.clear()
	presses.clear()
	_canvas.plan_outlines = []
	_refresh()
	if stamp_interval <= 0.0:
		for k in plan.size():
			_press_planned(k)
		_finish_run()
		return
	var tw := create_tween()
	tw.tween_interval(0.15)
	for k in plan.size():
		tw.tween_callback(_press_planned.bind(k))
		tw.tween_interval(stamp_interval)
	tw.tween_callback(_finish_run)


func _press_planned(k: int) -> void:
	var e: Array = plan[k]
	presses.append(e.duplicate())
	board.press(level.stamps[e[0]], e[1], e[2])
	_strip.active_index = k
	_strip.refresh()
	_canvas.queue_redraw()
	if stamp_interval > 0.0:
		_canvas.animate_press()
		Audio.play_press()
		Haptics.tap(20)


func _finish_run() -> void:
	busy = false
	_strip.active_index = -1
	if board.matches(level.target()):
		_on_win()
		return
	failed_runs += 1
	_showing_run = true
	_seal.crack()
	var wrong := Solver.first_wrong(level, presses)
	if wrong >= 0:
		_strip.bad_index = wrong
		_message.text = "Stamp %d breaks the picture. Fix your plan, then stamp again." % (wrong + 1)
	else:
		_message.text = "So far so good, but the picture isn't finished yet."
	Analytics.event("plan_failed", {"level": level.id, "run": failed_runs, "wrong_slot": wrong})
	Audio.play_error()
	Haptics.tap(40)
	_canvas.shake()
	_refresh()


# --- hints ----------------------------------------------------------------

## Two steps: first a "look here" ring on the target, then the stamp itself.
func _on_hint() -> void:
	if won or busy:
		return
	_deselect()
	_clear_hint()
	hints_used += 1
	_seal.crack()
	Save.record_hint()
	var state := BoardState.new()
	var used := []
	var sequence: Array = plan if is_plan_mode() else presses
	for p in sequence:
		state.press(level.stamps[p[0]], p[1], p[2])
		used.append(p[0])
	if is_plan_mode():
		var wrong := Solver.first_wrong(level, plan)
		if wrong >= 0:
			_strip.bad_index = wrong
			_strip.refresh()
			_message.text = "Stamp %d in your plan can't be right." % (wrong + 1)
			Analytics.event("hint_used", {"level": level.id, "kind": "wrong_slot"})
			return
	var h: Variant = Solver.hint(level, state, used)
	if h == null:
		if state.matches(level.target()):
			_message.text = "Your plan is complete. Hit STAMP!"
		else:
			_message.text = "Something is on top that shouldn't be. Undo the last stamp."
			_pulse(_undo_btn)
		Analytics.event("hint_used", {"level": level.id, "kind": "none"})
		return
	var i: int = h[0]
	if _hint_step == 0 or _hint_stamp != i:
		_hint_step = 1
		_hint_stamp = i
		_target.set_clue(_clue_cells(h))
		_message.text = "Look here on the target. What has to go down first?"
		Analytics.event("hint_used", {"level": level.id, "kind": "look_here"})
		return
	_hint_step = 2
	_buttons[i].hinted = true
	_canvas.set_hint(h)
	var s := level.stamps[i]
	var verb := "Add this one to your plan next" if is_plan_mode() else "Press this one next"
	if s.rotatable and not _rot_matches_hint(i):
		_message.text = "%s, but turn it first: tap and hold it." % verb
	elif s.spot_count() > 1:
		_message.text = "%s, on the glowing spot." % verb
	else:
		_message.text = "%s." % verb
	Analytics.event("hint_used", {"level": level.id, "kind": "stamp"})


## The clue for the next stamp: where later stamps cover it in the target
## (what sits on top tells you it goes underneath), or where it shows.
func _clue_cells(h: Array) -> Array:
	var s := level.stamps[h[0]]
	var t := level.target()
	var covered := []
	var showing := []
	for c in s.cells(h[1], h[2]):
		if t.get_at(c.x, c.y) == s.color:
			showing.append(c)
		else:
			covered.append(c)
	return covered if not covered.is_empty() else showing


func _pulse(c: Control) -> void:
	var tw := create_tween()
	c.pivot_offset = c.size * 0.5
	tw.tween_property(c, "scale", Vector2(1.2, 1.2), 0.15)
	tw.tween_property(c, "scale", Vector2.ONE, 0.15)


# --- finishing --------------------------------------------------------------

func _check_live_done() -> void:
	if board.matches(level.target()):
		_on_win()
	elif presses.size() == level.stamps.size():
		Audio.play_error()
		_canvas.shake()
		_message.text = "Not quite. Compare with the target, then undo."


func _on_win() -> void:
	won = true
	var s := stars()
	Save.record_win(level.id, level.global_index, s)
	var seconds := (Time.get_ticks_msec() - _started_at) / 1000.0
	Analytics.event("level_complete", {"level": level.id, "stars": s, "undos": undo_count, "restarts": restarts,
		"failed_runs": failed_runs, "hints": hints_used, "seconds": seconds})
	Analytics.event("undo_count", {"level": level.id, "count": undo_count, "completed": true})
	Audio.play_win()
	Haptics.success()
	_refresh()
	if stamp_interval <= 0.0:
		_win.show_result(level, s, Levels.next_index(level.global_index) >= 0, _colorblind(), presses.duplicate(true), _reason(s))
		return
	# The paper lifts off the desk before it is framed.
	_canvas.pivot_offset = _canvas.size * 0.5
	var tw := create_tween()
	tw.tween_property(_canvas, "scale", Vector2(1.05, 1.05), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_canvas, "position:y", _canvas.position.y - 24, 0.18)
	tw.tween_interval(0.25)
	tw.tween_callback(func() -> void:
		_canvas.scale = Vector2.ONE
		_canvas.position.y += 24
		_win.show_result(level, s, Levels.next_index(level.global_index) >= 0, _colorblind(), presses.duplicate(true), _reason(s)))


func _reason(s: int) -> String:
	match s:
		3:
			return "Perfect: first try, no hints!" if is_plan_mode() else "Perfect: no undos, no hints."
		2:
			return "Solved after a retry. Get it first time for 3 stars." if is_plan_mode() else "Solved with undos. Try it clean for 3 stars."
	return "Solved with a hint. Replay without one for more stars."


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
	_strip.colorblind = cb
	if is_plan_mode() and not _showing_run and not busy:
		_canvas.plan_outlines = plan
	_canvas.queue_redraw()
	_target.queue_redraw()
	_strip.refresh()
	for b in _buttons:
		b.used = is_used(b.index)
		b.colorblind = cb
		b.queue_redraw()
	if is_plan_mode():
		_undo_btn.disabled = won or busy or plan.is_empty()
		_restart_btn.disabled = won or busy or (plan.is_empty() and not _showing_run)
		_stamp_btn.disabled = won or busy or plan.is_empty()
		_progress.total = level.solution.size()
		_progress.done = plan.size()
	else:
		_undo_btn.disabled = won or not stack.can_undo()
		_restart_btn.disabled = won or presses.is_empty()
		_progress.total = level.solution.size()
		_progress.done = presses.size()
	_hint_btn.disabled = won or busy


func _log_quit(reason: String) -> void:
	if won or _quit_logged or level == null:
		return
	_quit_logged = true
	var seconds := (Time.get_ticks_msec() - _started_at) / 1000.0
	Analytics.event("quit_mid_level", {"level": level.id, "presses": presses.size(), "plan": plan.size(), "undos": undo_count,
		"failed_runs": failed_runs, "hints": hints_used, "seconds": seconds, "reason": reason})
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
