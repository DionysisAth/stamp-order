extends Node
## Loads the level JSON for every world, hands the current level to the game
## scene and knows what comes next.

const WORLD_FILES := [
	"res://levels/world_1.json",
	"res://levels/world_2.json",
	"res://levels/world_3.json",
]

## [{number, name, twist, palette, levels: Array[Level]}]
var worlds: Array[Dictionary] = []
var all: Array[Level] = []
var current_index := 0


func _ready() -> void:
	load_all()


func load_all() -> void:
	worlds.clear()
	all.clear()
	for w in WORLD_FILES.size():
		var text := FileAccess.get_file_as_string(WORLD_FILES[w])
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("Could not read %s" % WORLD_FILES[w])
			continue
		var world := {
			"number": w + 1,
			"name": str(parsed.get("name", "World %d" % (w + 1))),
			"twist": str(parsed.get("twist", "")),
			"palette": str(parsed.get("palette", "garden")),
			"levels": [],
		}
		var n := 0
		for entry in parsed.get("levels", []):
			var level := Level.from_dict(entry)
			n += 1
			level.world = w + 1
			level.number = n
			level.global_index = all.size()
			all.append(level)
			world["levels"].append(level)
		worlds.append(world)


func count() -> int:
	return all.size()


func get_level(index: int) -> Level:
	return all[clampi(index, 0, all.size() - 1)]


func current() -> Level:
	return get_level(current_index)


## Index of the level after `index`, or -1 after the last one.
func next_index(index: int) -> int:
	return index + 1 if index + 1 < all.size() else -1


func world_info(world_number: int) -> Dictionary:
	return worlds[world_number - 1]


func label(level: Level) -> String:
	return "%d-%d" % [level.world, level.number]


## The level the Play button should open: the first unlocked one not yet
## completed, or the last unlocked one.
func continue_index() -> int:
	var unlocked := mini(Save.unlocked_count(), all.size())
	for i in unlocked:
		if not Save.is_completed(all[i].id):
			return i
	return maxi(unlocked - 1, 0)
