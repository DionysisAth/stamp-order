class_name FreeLevel
extends RefCounted
## Prototype A level: a set of stamp types with a number of uses each. Stamps
## are not pinned to spots: the player drags them anywhere on the paper.
## The target is rebuilt from the solution: [[type, x, y, rot], ...].

var id := ""
var title := ""
var tip := ""
var palette := "garden"
## [{shape, size, color, uses, rotatable}]
var types: Array = []
var solution: Array = []
var _target: BoardState


static func from_dict(d: Dictionary) -> FreeLevel:
	var l := FreeLevel.new()
	l.id = str(d.get("id", ""))
	l.title = str(d.get("title", ""))
	l.tip = str(d.get("tip", ""))
	l.palette = str(d.get("palette", "garden"))
	for t in d.get("stamps", []):
		l.types.append({"shape": str(t["shape"]), "size": int(t["size"]), "color": int(t["color"]),
			"uses": int(t.get("uses", 1)), "rotatable": bool(t.get("rotatable", false))})
	for s in d.get("solution", []):
		l.solution.append([int(s[0]), int(s[1]), int(s[2]), int(s[3])])
	return l


func to_dict() -> Dictionary:
	return {"id": id, "title": title, "tip": tip, "palette": palette, "stamps": types.duplicate(true), "solution": solution.duplicate(true)}


static func cells_of(t: Dictionary, x: int, y: int, rot: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in Shapes.mask(t["shape"], t["size"], rot):
		out.append(Vector2i(x, y) + c)
	return out


func press(board: BoardState, p: Array) -> void:
	var t: Dictionary = types[p[0]]
	board.press_cells(cells_of(t, p[1], p[2], p[3]), t["color"])


func target() -> BoardState:
	if _target == null:
		_target = BoardState.new()
		for p in solution:
			press(_target, p)
	return _target


## A throwaway Level (one pinned StampDef per press) so CanvasView can draw
## free presses with the normal renderer.
func as_canvas_level(presses: Array) -> Array:
	var l := Level.new()
	l.id = id
	l.palette = palette
	var mapped := []
	for p in presses:
		var t: Dictionary = types[p[0]]
		var s := StampDef.new()
		s.shape = t["shape"]
		s.size = t["size"]
		s.color = t["color"]
		s.placements = [{"x": p[1], "y": p[2], "rot": p[3]}]
		l.stamps.append(s)
		mapped.append([l.stamps.size() - 1, 0, p[3]])
	return [l, mapped]
