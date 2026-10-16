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
	dim.color = Color(0.18, 0.14, 0.1, 0.45)
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
	_title.theme_type_variation = "HeaderLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	var frame := PanelContainer.new()
	var fsb := UITheme.box(UITheme.FRAME, 10, true)
	fsb.set_content_margin_all(16)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(frame)
	_picture = CanvasView.new()
	_picture.thumbnail = true
	_picture.custom_minimum_size = Vector2(300, 300)
	frame.add_child(_picture)

	_stars = StarsView.new(0, Vector2(300, 90))
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


func show_result(level: Level, stars: int, has_next: bool, colorblind: bool) -> void:
	_title.text = "Framed for the gallery!" if level.picture else "Solved!"
	_picture.colorblind = colorblind
	_picture.show_target(level)
	match stars:
		3:
			_reason.text = "Perfect: no undos, no hints."
		2:
			_reason.text = "Solved with undos. Try it clean for 3 stars."
		_:
			_reason.text = "Solved with a hint. Replay without one for more stars."
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


func hide_panel() -> void:
	visible = false
