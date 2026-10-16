class_name Level
extends RefCounted
## A level as loaded from levels/world_N.json. The target picture is never
## stored: pressing the solution rebuilds it, so it cannot drift out of sync.

var id := ""
var title := ""
var tip := ""
var palette := "garden"
var picture := false
var stamps: Array[StampDef] = []
## Bottom-up list of [stamp_index, placement_index].
var solution: Array = []
## Filled in by the Levels autoload.
var world := 1
var number := 1
var global_index := 0

var _target: BoardState


static func from_dict(d: Dictionary) -> Level:
	var l := Level.new()
	l.id = str(d.get("id", ""))
	l.title = str(d.get("title", ""))
	l.tip = str(d.get("tip", ""))
	l.palette = str(d.get("palette", "garden"))
	l.picture = bool(d.get("picture", false))
	for s in d.get("stamps", []):
		l.stamps.append(StampDef.from_dict(s))
	for step in d.get("solution", []):
		l.solution.append([int(step[0]), int(step[1])])
	return l


func to_dict() -> Dictionary:
	var d := {"id": id, "palette": palette}
	if title != "":
		d["title"] = title
	if tip != "":
		d["tip"] = tip
	if picture:
		d["picture"] = true
	var list := []
	for s in stamps:
		list.append(s.to_dict())
	d["stamps"] = list
	d["solution"] = solution.duplicate(true)
	return d


## The solution as presses: [stamp_index, spot, rot], bottom-up.
func solution_presses() -> Array:
	var out := []
	for step in solution:
		var s := stamps[step[0]]
		out.append([step[0], step[1], int(s.placements[step[1]]["rot"])])
	return out


func target() -> BoardState:
	if _target == null:
		_target = BoardState.new()
		for p in solution_presses():
			_target.press(stamps[p[0]], p[1], p[2])
	return _target


func uses_two_spots() -> bool:
	for s in stamps:
		if s.spot_count() > 1:
			return true
	return false


func uses_rotation() -> bool:
	for s in stamps:
		if s.rotatable:
			return true
	return false


## Basic sanity checks; returns a list of problems (empty when valid).
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if stamps.is_empty():
		problems.append("%s: no stamps" % id)
	if solution.size() != stamps.size():
		problems.append("%s: solution must use every stamp exactly once" % id)
	var seen := {}
	for step in solution:
		var si: int = step[0]
		if si < 0 or si >= stamps.size():
			problems.append("%s: solution refers to missing stamp %d" % [id, si])
			continue
		if seen.has(si):
			problems.append("%s: stamp %d used twice" % [id, si])
		seen[si] = true
		if step[1] < 0 or step[1] >= stamps[si].spot_count():
			problems.append("%s: stamp %d has no placement %d" % [id, si, step[1]])
	for i in stamps.size():
		var s := stamps[i]
		if not Shapes.has_shape(s.shape):
			problems.append("%s: stamp %d has unknown shape %s" % [id, i, s.shape])
		if s.placements.is_empty():
			problems.append("%s: stamp %d has no placements" % [id, i])
		for spot in s.spot_count():
			var o := s.origin(spot)
			if o.x < 0 or o.y < 0 or o.x + s.size > BoardState.SIZE or o.y + s.size > BoardState.SIZE:
				problems.append("%s: stamp %d placement %d leaves the canvas" % [id, i, spot])
	return problems
