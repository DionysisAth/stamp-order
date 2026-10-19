extends Screen
## Prototype A: Free Stamp. Stamps are not pinned to spots. Drag a stamp from
## the tray to anywhere on the paper (tap it first to turn it); some stamps
## can be pressed twice. Work out where each one went, and in what order.

var levels: Array[FreeLevel] = []
var index := 0
var level: FreeLevel
var board := BoardState.new()
## Presses so far: [type, x, y, rot].
var presses: Array = []
var uses_left: Array = []
var undo_count := 0
var hints_used := 0
var won := false

var _history: Array = []
var _title: Label
var _name: Label
var _tip: Label
var _message: Label
var _target: CanvasView
var _canvas: FreeCanvas
var _tray: HBoxContainer
var _buttons: Array[FreeStampButton] = []
var _undo_btn: IconButton
var _restart_btn: IconButton
var _win: WinPanel
var _hint: Array = []


func background_key() -> String:
	return "kitchen"


func build() -> void:
	levels = FreeLevels.load_all()
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	bar.add_child(IconButton.create("back", on_back))
	_title = make_label("", "HeaderLabel")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_title)
	bar.add_child(IconButton.create("hint", _on_hint))
	_undo_btn = IconButton.create("undo", _on_undo)
	_restart_btn = IconButton.create("restart", _on_restart)
	bar.add_child(_undo_btn)
	bar.add_child(_restart_btn)
	body.add_child(bar)

	var card := PanelContainer.new()
	var csb := UITheme.box(UITheme.CARD, 30, true)
	csb.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", csb)
	body.add_child(card)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	card.add_child(header)
	_target = CanvasView.new()
	_target.thumbnail = true
	_target.custom_minimum_size = Vector2(250, 250)
	_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_target)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(info)
	var pill := Label.new()
	pill.text = "A · FREE STAMP"
	pill.label_settings = UITheme.label_settings(20, Color.WHITE)
	pill.add_theme_stylebox_override("normal", UITheme.box(UITheme.ACCENT, 16))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	info.add_child(pill)
	_name = Label.new()
	_name.label_settings = UITheme.label_settings(32, UITheme.INK)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_name)
	_tip = make_label("", "SubtleLabel", HORIZONTAL_ALIGNMENT_LEFT)
	_tip.add_theme_font_size_override("font_size", 23)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(_tip)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.label_settings = UITheme.label_settings(23, UITheme.ACCENT)
	info.add_child(_message)

	_canvas = FreeCanvas.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size = Vector2(0, 420)
	_canvas.hovered.connect(_on_hover)
	_canvas.hover_ended.connect(_clear_ghost)
	_canvas.dropped.connect(_on_drop)
	body.add_child(_canvas)

	var tray_center := CenterContainer.new()
	body.add_child(tray_center)
	_tray = HBoxContainer.new()
	_tray.add_theme_constant_override("separation", 14)
	tray_center.add_child(_tray)

	_win = WinPanel.new()
	add_child(_win)
	_win.next_pressed.connect(func() -> void:
		if index + 1 < levels.size():
			start_level(index + 1)
		else:
			Router.goto("prototypes"))
	_win.replay_pressed.connect(func() -> void: start_level(index))
	_win.levels_pressed.connect(func() -> void: Router.goto("prototypes"))
	start_level(clampi(int(Router.params.get("index", 0)), 0, levels.size() - 1))


func start_level(i: int) -> void:
	index = i
	level = levels[i]
	board.clear()
	presses.clear()
	_history.clear()
	uses_left.clear()
	undo_count = 0
	hints_used = 0
	won = false
	_hint = []
	_win.hide_panel()
	background.colors = UITheme.world_gradient(i % 4 + 1)
	_title.text = "Level %d" % (i + 1)
	_name.text = level.title if level.title != "" else "Free stamp %d" % (i + 1)
	_tip.text = level.tip
	_message.text = ""
	var target_view := level.as_canvas_level(level.solution)
	_target.show_level(target_view[0], target_view[1], level.target())
	_canvas.type_sizes.clear()
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	for t in level.types.size():
		var info: Dictionary = level.types[t]
		uses_left.append(info["uses"])
		_canvas.type_sizes.append(info["size"])
		var b := FreeStampButton.new(t, info, level.palette)
		b.uses_left = info["uses"]
		b.turned.connect(func(_t: int) -> void: _clear_hint())
		_tray.add_child(b)
		_buttons.append(b)
	_redraw()
	Analytics.event("proto_level_start", {"mode": "free", "level": level.id})


## Presses stamp type `t` with its top-left at `cell` and the tray's rotation.
func press(t: int, cell: Vector2i) -> void:
	if won or uses_left[t] <= 0:
		return
	_history.append([board.cells.duplicate(), t])
	var p := [t, cell.x, cell.y, _buttons[t].rot]
	presses.append(p)
	level.press(board, p)
	uses_left[t] -= 1
	_buttons[t].uses_left = uses_left[t]
	_clear_hint()
	_message.text = ""
	_redraw()
	_canvas.animate_press()
	Audio.play_press()
	Haptics.tap(20)
	if board.matches(level.target()):
		_on_win()
	elif _all_used():
		Audio.play_error()
		_canvas.shake()
		_message.text = "Not quite. Undo and look again: what's hiding underneath?"


func _all_used() -> bool:
	for u in uses_left:
		if u > 0:
			return false
	return true


func _on_hover(t: int, cell: Vector2i) -> void:
	if won or uses_left[t] <= 0:
		return
	_redraw([t, cell.x, cell.y, _buttons[t].rot])


func _clear_ghost() -> void:
	_redraw()


func _on_drop(t: int, cell: Vector2i) -> void:
	press(t, cell)


## Rebuilds the canvas from the presses, plus an optional ghost press and the
## hint outline.
func _redraw(ghost: Array = []) -> void:
	var extra := presses.duplicate()
	if not ghost.is_empty():
		extra.append(ghost)
	if not _hint.is_empty():
		extra.append(_hint)
	var view := level.as_canvas_level(extra)
	var lvl: Level = view[0]
	var mapped: Array = view[1]
	_canvas.level = lvl
	_canvas.board = board
	_canvas.presses = mapped.slice(0, presses.size())
	_canvas.ghost_stamp = -1
	_canvas.hint_pose = []
	var k := presses.size()
	if not ghost.is_empty():
		_canvas.ghost_stamp = k
		_canvas.ghost_rot = ghost[3]
		k += 1
	if not _hint.is_empty():
		_canvas.hint_pose = [k, 0, _hint[3]]
	_canvas.colorblind = bool(Save.get_setting("colorblind"))
	_canvas._update_pulse()
	_canvas.queue_redraw()
	_undo_btn.disabled = won or presses.is_empty()
	_restart_btn.disabled = won or presses.is_empty()


func _clear_hint() -> void:
	_hint = []
	for b in _buttons:
		b.hinted = false


func _on_undo() -> void:
	if won or _history.is_empty():
		return
	var last: Array = _history.pop_back()
	board.cells = last[0]
	presses.pop_back()
	uses_left[last[1]] += 1
	_buttons[last[1]].uses_left = uses_left[last[1]]
	undo_count += 1
	_clear_hint()
	_message.text = ""
	Audio.play_undo()
	_redraw()


func _on_restart() -> void:
	if won:
		return
	while not _history.is_empty():
		_on_undo()


func _on_hint() -> void:
	if won:
		return
	hints_used += 1
	_clear_hint()
	var h: Variant = FreeSolver.hint(level, board, uses_left)
	if h == null:
		_message.text = "This can't become the target any more. Undo a stamp."
		_redraw()
		return
	_hint = h
	_buttons[h[0]].hinted = true
	var turn: bool = _buttons[h[0]].rot != h[3] and level.types[h[0]].get("rotatable", false)
	_message.text = "Press this stamp on the glowing outline%s." % (" (turn it first)" if turn else "")
	_redraw()


func stars() -> int:
	if hints_used > 0:
		return 1
	if undo_count > 0:
		return 2
	return 3


func _on_win() -> void:
	won = true
	var s := stars()
	var best: Dictionary = Save.data.get("proto", {})
	best["free_%d" % index] = maxi(s, int(best.get("free_%d" % index, 0)))
	Save.data["proto"] = best
	Save.write()
	Analytics.event("proto_level_complete", {"mode": "free", "level": level.id, "stars": s, "undos": undo_count, "hints": hints_used})
	Audio.play_win()
	Haptics.success()
	_redraw()
	var view := level.as_canvas_level(presses)
	var reason := "Perfect: no undos, no hints." if s == 3 else ("Solved with undos." if s == 2 else "Solved with a hint.")
	_win.show_result(view[0], s, true, bool(Save.get_setting("colorblind")), view[1], reason)


func on_back() -> void:
	Router.goto("prototypes")
