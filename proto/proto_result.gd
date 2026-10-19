class_name ProtoResult
extends Control
## Win / lose card for the prototypes.

signal primary
signal secondary
signal tertiary

var _title: Label
var _text: Label
var _stars: StarsView
var _buttons: Array[Button] = []
var _card: PanelContainer


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
	_card.custom_minimum_size = Vector2(540, 0)
	center.add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_card.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.label_settings = UITheme.label_settings(52, UITheme.ACCENT)
	box.add_child(_title)
	_stars = StarsView.new(0, Vector2(330, 100))
	_stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_stars)
	_text = Label.new()
	_text.theme_type_variation = "SubtleLabel"
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)
	var sigs := [primary, secondary, tertiary]
	for k in 3:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 100 if k == 0 else 86)
		if k == 0:
			b.theme_type_variation = "AccentButton"
		var sig: Signal = sigs[k]
		b.pressed.connect(func() -> void:
			Audio.play_click()
			sig.emit())
		box.add_child(b)
		_buttons.append(b)


## labels: up to three button texts (empty hides the button).
func show_card(title: String, text: String, stars: int, labels: Array, celebrate: bool) -> void:
	_title.text = title
	_text.text = text
	_stars.visible = stars > 0
	if stars > 0:
		_stars.pop_in(stars, 0.2)
	for k in 3:
		var label: String = labels[k] if k < labels.size() else ""
		_buttons[k].text = label
		_buttons[k].visible = label != ""
	visible = true
	modulate.a = 0.0
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.9, 0.9)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if celebrate:
		var confetti := Confetti.new(size.x)
		confetti.position = Vector2(size.x * 0.5, -30)
		add_child(confetti)
		confetti.burst()


func hide_card() -> void:
	visible = false
