extends Node
## Local save: one JSON file in user:// with progress, stars and settings.
## Written after every win and every settings change.

signal settings_changed(key: String, value: Variant)
signal progress_changed

const VERSION := 1

var path := "user://save.json"
var data := {}


func _ready() -> void:
	load_data()


func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"stars": {},
		"unlocked": 1,
		"hints_used": 0,
		"settings": {"sound": true, "haptics": true, "colorblind": false},
	}


func load_data() -> void:
	data = defaults()
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file unreadable, starting fresh")
		return
	for key in parsed:
		if key == "settings" and typeof(parsed[key]) == TYPE_DICTIONARY:
			data["settings"].merge(parsed[key], true)
		else:
			data[key] = parsed[key]


func write() -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("Could not replace save file: %s" % error_string(err))


func stars_for(level_id: String) -> int:
	return int(data["stars"].get(level_id, 0))


func is_completed(level_id: String) -> bool:
	return data["stars"].has(level_id)


func is_unlocked(global_index: int) -> bool:
	return global_index < int(data["unlocked"])


func unlocked_count() -> int:
	return int(data["unlocked"])


## Stores the best star count and unlocks the next level. Stars never block
## progress: any win unlocks what comes next.
func record_win(level_id: String, global_index: int, stars: int) -> void:
	data["stars"][level_id] = maxi(stars, stars_for(level_id))
	data["unlocked"] = maxi(int(data["unlocked"]), global_index + 2)
	write()
	progress_changed.emit()


func record_hint() -> void:
	data["hints_used"] = int(data["hints_used"]) + 1


func total_stars() -> int:
	var total := 0
	for k in data["stars"]:
		total += int(data["stars"][k])
	return total


func get_setting(key: String) -> Variant:
	return data["settings"].get(key)


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	write()
	settings_changed.emit(key, value)


func reset_progress() -> void:
	var settings: Dictionary = data["settings"]
	data = defaults()
	data["settings"] = settings
	write()
	progress_changed.emit()
