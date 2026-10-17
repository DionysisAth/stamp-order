extends Screen
## Sound, haptics, colourblind mode and progress reset.

var _confirm: ConfirmationDialog
var _swatches: HBoxContainer


func background_key() -> String:
	return "settings"


func build() -> void:
	body.add_child(make_top_bar("Settings"))
	var card := PanelContainer.new()
	body.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	box.add_child(_toggle("Sound", "sound"))
	box.add_child(_toggle("Haptics", "haptics"))
	box.add_child(_toggle("Colourblind mode", "colorblind"))
	var hint := make_label("Adds a symbol to every ink colour, so no picture depends on telling colours apart.", "SubtleLabel", HORIZONTAL_ALIGNMENT_LEFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	_swatches = HBoxContainer.new()
	_swatches.alignment = BoxContainer.ALIGNMENT_CENTER
	_swatches.add_theme_constant_override("separation", 8)
	box.add_child(_swatches)
	_build_swatches()

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	body.add_child(make_button("Reset progress", _ask_reset))
	body.add_child(make_label("Stamp Order %s" % ProjectSettings.get_setting("application/config/version", ""), "OnColorLabel"))

	_confirm = ConfirmationDialog.new()
	_confirm.dialog_text = "Erase all stars and unlocked levels?"
	_confirm.ok_button_text = "Erase"
	_confirm.confirmed.connect(func() -> void: Save.reset_progress())
	add_child(_confirm)


func _toggle(text: String, key: String) -> SwitchButton:
	var c := SwitchButton.new(text, bool(Save.get_setting(key)))
	c.toggled.connect(func(on: bool) -> void:
		Save.set_setting(key, on)
		Audio.play_click()
		if key == "colorblind":
			_build_swatches())
	return c


func _build_swatches() -> void:
	for c in _swatches.get_children():
		c.queue_free()
	var cb := bool(Save.get_setting("colorblind"))
	for id in range(1, Palettes.COLOR_COUNT + 1):
		var sw := Swatch.new()
		sw.color_id = id
		sw.show_symbol = cb
		_swatches.add_child(sw)


func _ask_reset() -> void:
	_confirm.popup_centered()


class Swatch extends Control:
	var color_id := 1
	var show_symbol := false

	func _init() -> void:
		custom_minimum_size = Vector2(66, 66)

	func _draw() -> void:
		var col := Palettes.color("garden", color_id)
		draw_circle(size * 0.5 + Vector2(0, 3), size.x * 0.42, col.darkened(0.25), true, -1.0, true)
		draw_circle(size * 0.5, size.x * 0.42, col, true, -1.0, true)
		draw_circle(size * 0.5 - Vector2(size.x * 0.1, size.x * 0.12), size.x * 0.12, Color(1, 1, 1, 0.45), true, -1.0, true)
		if show_symbol:
			InkSymbols.draw(self, color_id, size * 0.5, size.x * 0.2, Palettes.contrast(col))
