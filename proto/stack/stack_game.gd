extends Screen
## Prototype B: Sticker Stack. Tap stickers that nothing covers to move them
## into the 7-slot tray; three alike clear. Fill the tray and you lose.

const LEVEL_COUNT := 10

## Seconds a sticker takes to fly to the tray (0 = instant, for tests).
var flight_seconds := 0.2

var number := 1
var level: StackLevel
var present: Array = []
var tray: Array = []
var undo_count := 0
var hints_used := 0
var cleared := 0
var won := false
var lost := false
var busy := false

var _history: Array = []
var _title: Label
var _tip: Label
var _view: StackView
var _undo_btn: IconButton
var _result: ProtoResult
var _combo := 0


func background_key() -> String:
	return "menu"


func build() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	bar.add_child(IconButton.create("back", on_back))
	_title = make_label("", "HeaderLabel")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_title)
	bar.add_child(IconButton.create("hint", _on_hint))
	_undo_btn = IconButton.create("undo", _on_undo)
	bar.add_child(_undo_btn)
	bar.add_child(IconButton.create("restart", func() -> void: start_level(number)))
	body.add_child(bar)

	var pill := Label.new()
	pill.text = "B · STICKER STACK"
	pill.label_settings = UITheme.label_settings(20, Color.WHITE)
	pill.add_theme_stylebox_override("normal", UITheme.box(UITheme.ACCENT, 16))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(pill)
	_tip = make_label("", "OnColorLabel")
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_tip)

	_view = StackView.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.tile_tapped.connect(pick)
	body.add_child(_view)

	_result = ProtoResult.new()
	add_child(_result)
	_result.primary.connect(_on_result_primary)
	_result.secondary.connect(func() -> void:
		if lost and not _history.is_empty():
			_result.hide_card()
			lost = false
			_on_undo()
		else:
			start_level(number))
	_result.tertiary.connect(func() -> void: Router.goto("prototypes"))
	start_level(clampi(int(Router.params.get("index", 0)) + 1, 1, LEVEL_COUNT))


func start_level(n: int) -> void:
	number = n
	level = StackLevel.generate(n)
	present.clear()
	for t in level.tiles:
		present.append(true)
	tray.clear()
	_history.clear()
	undo_count = 0
	hints_used = 0
	cleared = 0
	won = false
	lost = false
	busy = false
	_combo = 0
	_result.hide_card()
	background.colors = UITheme.world_gradient((n - 1) % 4 + 1)
	_title.text = "Level %d" % n
	_tip.text = level.tip if level.tip != "" else "%d stickers. Clear them all." % level.tiles.size()
	_view.level = level
	_view.present = present
	_view.tray = tray
	_view.hint_index = -1
	_view.flights.clear()
	_refresh()
	Analytics.event("proto_level_start", {"mode": "stack", "level": n})


## Tapping a sticker: covered ones shake; free ones fly to the tray.
func pick(i: int) -> void:
	if won or lost or busy or not present[i]:
		return
	if not level.is_free(i, present):
		_view.shake(i)
		Audio.play_error()
		Haptics.tap(15)
		return
	var type: int = level.tiles[i]["type"]
	_history.append({"tile": i, "tray": tray.duplicate(), "cleared": cleared})
	present[i] = false
	var at := tray.size()
	for k in tray.size():
		if tray[k] == type:
			at = k + 1
	tray.insert(at, type)
	_view.hint_index = -1
	Audio.play_press()
	Haptics.tap(15)
	if flight_seconds <= 0.0:
		_settle(type)
		return
	busy = true
	var flight := {"type": type, "from": _view.tile_rect(i), "to": _view.slot_rect(mini(at, StackView.TRAY_SLOTS - 1)), "t": 0.0}
	_view.flights.append(flight)
	var shown := tray.duplicate()
	tray.remove_at(at)
	_view.tray = tray
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		flight["t"] = v
		_view.queue_redraw(), 0.0, 1.0, flight_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		_view.flights.erase(flight)
		tray.assign(shown)
		busy = false
		_settle(type))
	_refresh()


## After a sticker lands: clear a triple, then check for a win or a full tray.
func _settle(type: int) -> void:
	if tray.count(type) >= 3:
		var slots := []
		for k in tray.size():
			if tray[k] == type:
				slots.append(k)
		for k in slots:
			var splat := InkSplat.new()
			var r := _view.slot_rect(k)
			splat.position = r.get_center()
			splat.setup(Palettes.color(level.palette, level.types[type]["color"]), r.size.x)
			_view.add_child(splat)
		for k in 3:
			tray.erase(type)
		cleared += 1
		_combo += 1
		if _combo >= 2:
			Audio.play_win()
		else:
			Audio.play_rotate()
		Haptics.success()
	else:
		_combo = 0
	if present.count(true) == 0 and tray.is_empty():
		_on_win()
	elif tray.size() >= StackView.TRAY_SLOTS:
		_on_lose()
	_refresh()


func _on_undo() -> void:
	if won or busy or _history.is_empty():
		return
	var last: Dictionary = _history.pop_back()
	present[last["tile"]] = true
	tray.assign(last["tray"])
	cleared = last["cleared"]
	undo_count += 1
	lost = false
	Audio.play_undo()
	_refresh()


## Suggests a free sticker: one that completes a triple, else one that pairs
## up, else the free sticker whose type has the most copies showing.
func _on_hint() -> void:
	if won or lost or busy:
		return
	hints_used += 1
	var best := -1
	var best_score := -1
	for i in level.tiles.size():
		if not present[i] or not level.is_free(i, present):
			continue
		var type: int = level.tiles[i]["type"]
		var score := tray.count(type) * 10
		for j in level.tiles.size():
			if present[j] and j != i and level.tiles[j]["type"] == type and level.is_free(j, present):
				score += 3
		if score > best_score:
			best_score = score
			best = i
	_view.hint_index = best
	_refresh()


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
	best["stack_%d" % (number - 1)] = maxi(s, int(best.get("stack_%d" % (number - 1), 0)))
	Save.data["proto"] = best
	Save.write()
	Analytics.event("proto_level_complete", {"mode": "stack", "level": number, "stars": s, "undos": undo_count, "hints": hints_used})
	Audio.play_win()
	_result.show_card("Cleared!", "%d stickers cleared." % level.tiles.size(), s,
		["Next level" if number < LEVEL_COUNT else "Back to modes", "Replay", "Modes"], true)


func _on_lose() -> void:
	lost = true
	Analytics.event("proto_level_failed", {"mode": "stack", "level": number, "left": present.count(true)})
	Audio.play_error()
	_result.show_card("Tray full!", "No room left for another sticker.", 0, ["Try again", "Undo last pick", "Modes"], false)


func _on_result_primary() -> void:
	if won and number < LEVEL_COUNT:
		start_level(number + 1)
	elif won:
		Router.goto("prototypes")
	else:
		start_level(number)


func _refresh() -> void:
	_undo_btn.disabled = won or _history.is_empty()
	_view.queue_redraw()


func on_back() -> void:
	Router.goto("prototypes")
