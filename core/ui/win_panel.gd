class_name WinPanel
extends Control
## Shown when the canvas matches the target: the picture is framed, stars pop
## in and the player chooses what comes next.

signal next_pressed
signal replay_pressed
signal levels_pressed

var _card: PanelContainer
var _title: Label
var _reason: Label
var _picture: CanvasView
var _stars: StarsView
var _next: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.04, 0.3, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(560, 0)
	center.add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_card.add_child(box)

	_title = Label.new()
	_title.label_settings = UITheme.label_settings(48, UITheme.ACCENT, 0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)

	var frame := PanelContainer.new()
	var fsb := UITheme.candy(UITheme.FRAME, UITheme.FRAME.darkened(0.25), 18, 8)
	fsb.set_content_margin_all(18)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(frame)
	_picture = CanvasView.new()
	_picture.thumbnail = true
	_picture.custom_minimum_size = Vector2(300, 300)
	frame.add_child(_picture)

	_stars = StarsView.new(0, Vector2(330, 100))
	_stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_stars)

	_reason = Label.new()
	_reason.theme_type_variation = "SubtleLabel"
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_reason)

	_next = Button.new()
	_next.text = "Next level"
	_next.theme_type_variation = "AccentButton"
	_next.custom_minimum_size = Vector2(0, 104)
	_next.pressed.connect(func() -> void:
		Audio.play_click()
		next_pressed.emit())
	box.add_child(_next)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for spec in [["Replay", replay_pressed], ["Levels", levels_pressed]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(0, 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sig: Signal = spec[1]
		b.pressed.connect(func() -> void:
			Audio.play_click()
			sig.emit())
		row.add_child(b)


## Shows the result and replays the player's own order, numbering each
## layer, so they can see the structure they worked out.
func show_result(level: Level, stars: int, has_next: bool, colorblind: bool, order: Array = [], reason: String = "") -> void:
	_title.text = "Framed for the gallery!" if level.picture else "Solved!"
	_picture.colorblind = colorblind
	if order.is_empty():
		order = level.solution_presses()
	_replay(level, order)
	_reason.text = reason if reason != "" else "Solved!"
	_next.visible = has_next
	if not has_next:
		_title.text = "Every picture is framed!"
	visible = true
	modulate.a = 0.0
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.9, 0.9)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stars.pop_in(stars, 0.25)
	var confetti := Confetti.new(size.x)
	confetti.position = Vector2(size.x * 0.5, -30)
	add_child(confetti)
	confetti.burst()


func _replay(level: Level, order: Array) -> void:
	var board := BoardState.new()
	var shown: Array = []
	_picture.show_level(level, shown, board)
	_picture.numbered = true
	var tw := create_tween()
	tw.tween_interval(0.45)
	for p in order:
		tw.tween_callback(func() -> void:
			shown.append(p)
			board.press(level.stamps[p[0]], p[1], p[2])
			_picture.queue_redraw())
		tw.tween_interval(0.22)


func hide_panel() -> void:
	visible = false
