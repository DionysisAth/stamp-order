extends Control
## Level lab (editor-only). Review generator candidates one by one.
##
## 1. godot --headless --script res://tools/generate_levels.gd -- --candidates
## 2. Run this scene (F6 in the editor).
##
## Keys: Left/Right browse, 1/2/3 switch world, K keep, B bin, P play the
## solution step by step. Decisions go to res://tools/lab/review.json; the
## generator never picks a binned candidate again.

const REVIEW_PATH := "res://tools/lab/review.json"

var world := 1
var candidates: Array = []
var index := 0
var review := {"kept": [], "binned": []}
var _target: CanvasView
var _play: CanvasView
var _info: Label
var _level: Level
var _board := BoardState.new()
var _presses: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	_target = CanvasView.new()
	_play = CanvasView.new()
	for v in [_target, _play]:
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(v)
	if FileAccess.file_exists(REVIEW_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REVIEW_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			review.merge(parsed, true)
	_load_world(1)


func _load_world(w: int) -> void:
	world = w
	index = 0
	candidates = []
	var path := "res://tools/lab/candidates_w%d.json" % w
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			candidates = parsed.get("candidates", [])
	_show()


func _show() -> void:
	if candidates.is_empty():
		_info.text = "No candidates for world %d. Run the generator with -- --candidates first." % world
		return
	var c: Dictionary = candidates[index]
	_level = Level.from_dict(c["level"])
	_board.clear()
	_presses.clear()
	_target.show_target(_level)
	_play.show_level(_level, _presses, _board)
	var verdict := "kept" if review["kept"].has(c["key"]) else ("binned" if review["binned"].has(c["key"]) else "unreviewed")
	_info.text = "World %d  ·  candidate %d / %d  ·  slot %s  ·  score %d  ·  %d stamps  ·  %s\n←/→ browse   1/2/3 world   K keep   B bin   P press next stamp" % [
		world, index + 1, candidates.size(), c["slot"], c["score"], _level.stamps.size(), verdict]


func _decide(list: String) -> void:
	var key: String = candidates[index]["key"]
	for l in ["kept", "binned"]:
		review[l].erase(key)
	review[list].append(key)
	var f := FileAccess.open(REVIEW_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(review, "  "))
	f.close()
	index = mini(index + 1, candidates.size() - 1)
	_show()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	match k.keycode:
		KEY_RIGHT:
			index = mini(index + 1, maxi(candidates.size() - 1, 0))
			_show()
		KEY_LEFT:
			index = maxi(index - 1, 0)
			_show()
		KEY_1, KEY_2, KEY_3:
			_load_world(k.keycode - KEY_0)
		KEY_K:
			if not candidates.is_empty():
				_decide("kept")
		KEY_B:
			if not candidates.is_empty():
				_decide("binned")
		KEY_P:
			if _level != null and _presses.size() < _level.solution.size():
				var p: Array = _level.solution_presses()[_presses.size()]
				_presses.append(p)
				_board.press(_level.stamps[p[0]], p[1], p[2])
				_play.animate_press()
