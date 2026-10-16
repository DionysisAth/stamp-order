extends Node
## Screen navigation, the shared theme and the Android back button.

const SCENES := {
	"menu": "res://core/ui/main_menu.tscn",
	"levels": "res://core/ui/level_select.tscn",
	"gallery": "res://core/ui/gallery.tscn",
	"settings": "res://core/ui/settings.tscn",
	"game": "res://game/game.tscn",
}

## Parameters for the screen being opened (e.g. {"world": 2}).
var params := {}
var theme: Theme


func _ready() -> void:
	theme = UITheme.build()
	get_tree().root.theme = theme


func goto(screen: String, p: Dictionary = {}) -> void:
	params = p
	get_tree().change_scene_to_file.call_deferred(SCENES[screen])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("on_back"):
			scene.on_back()
		else:
			get_tree().quit()
