extends Screen
## Picks between the two new core-loop prototypes and their levels.

const MODES := [
	{
		"key": "free", "scene": "proto_free", "count": 10, "title": "A · Free Stamp",
		"text": "Drag stamps anywhere on the paper. Work out where each one went, and in what order. Some stamps can be pressed twice.",
		"color": Color("ff3d7f"),
	},
	{
		"key": "stack", "scene": "proto_stack", "count": 10, "title": "B · Sticker Stack",
		"text": "Peel stickers off the pile into a 7-slot tray. Three alike clear. Fill the tray and you lose.",
		"color": Color("3d8bff"),
	},
]


func background_key() -> String:
	return "menu"


func build() -> void:
	body.add_child(make_top_bar("New modes"))
	body.add_child(make_label("Two prototype ways to play. Try both!", "OnColorLabel"))
	for m in MODES:
		body.add_child(_card(m))


func _card(m: Dictionary) -> Control:
	var card := PanelContainer.new()
	var sb := UITheme.box(UITheme.CARD, 30, true)
	sb.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	var title := Label.new()
	title.text = m["title"]
	title.label_settings = UITheme.label_settings(40, m["color"])
	box.add_child(title)
	var text := make_label(m["text"], "SubtleLabel", HORIZONTAL_ALIGNMENT_LEFT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	var progress: Dictionary = Save.data.get("proto", {})
	var count: int = m["count"]
	for i in count:
		var stars := int(progress.get("%s_%d" % [m["key"], i], 0))
		var unlocked: bool = i == 0 or progress.has("%s_%d" % [m["key"], i - 1])
		var b := Button.new()
		b.text = str(i + 1)
		b.custom_minimum_size = Vector2(104, 84)
		b.disabled = not unlocked
		b.focus_mode = Control.FOCUS_NONE
		var face: Color = m["color"] if stars > 0 else UITheme.CARD
		var edge := face.darkened(0.25) if stars > 0 else UITheme.CARD_EDGE
		b.add_theme_stylebox_override("normal", UITheme.candy(face, edge, 22, 6))
		b.add_theme_stylebox_override("pressed", UITheme.candy(face, edge, 22, 6, true))
		if stars > 0:
			for c in ["font_color", "font_hover_color", "font_pressed_color"]:
				b.add_theme_color_override(c, Color.WHITE)
		var scene: String = m["scene"]
		var idx: int = i
		b.pressed.connect(func() -> void:
			Audio.play_click()
			Router.goto(scene, {"index": idx}))
		grid.add_child(b)
	return card
