class_name Screen
extends Control
## Base for every full-screen page: fills the window, respects the phone's
## safe area (notches) and offers small builders for common widgets.

var body: VBoxContainer
var _margin: MarginContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	_margin.add_child(body)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	build()


## Override to create the page's widgets inside `body`.
func build() -> void:
	pass


## Android back button / Escape. Override per screen.
func on_back() -> void:
	Router.goto("menu")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		on_back()


func _apply_safe_area() -> void:
	var top := 0.0
	var bottom := 0.0
	var screen_size := Vector2(DisplayServer.screen_get_size())
	var safe := DisplayServer.get_display_safe_area()
	var vp := get_viewport_rect().size
	if OS.has_feature("mobile") and screen_size.y > 0 and safe.size.y > 0:
		var scale := vp.y / screen_size.y
		top = safe.position.y * scale
		bottom = (screen_size.y - safe.end.y) * scale
	_margin.add_theme_constant_override("margin_left", 28)
	_margin.add_theme_constant_override("margin_right", 28)
	_margin.add_theme_constant_override("margin_top", int(24 + top))
	_margin.add_theme_constant_override("margin_bottom", int(24 + bottom))


func make_button(text: String, on_pressed: Callable, variation: String = "") -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, 96)
	b.pressed.connect(func() -> void:
		Audio.play_click()
		on_pressed.call())
	return b


func make_label(text: String, variation: String = "", align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	if variation != "":
		l.theme_type_variation = variation
	return l


## A top bar with a back button and a centred title.
func make_top_bar(title: String) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 88)
	var back := IconButton.create("back", on_back)
	bar.add_child(back)
	var l := make_label(title, "HeaderLabel")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(l)
	var spacer := Control.new()
	spacer.custom_minimum_size = back.custom_minimum_size
	bar.add_child(spacer)
	return bar
