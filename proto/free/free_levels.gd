class_name FreeLevels
extends RefCounted
## Loads prototype A's levels from proto/free/levels.json.

const PATH := "res://proto/free/levels.json"


static func load_all() -> Array[FreeLevel]:
	var out: Array[FreeLevel] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Could not read %s" % PATH)
		return out
	for d in parsed.get("levels", []):
		out.append(FreeLevel.from_dict(d))
	return out
