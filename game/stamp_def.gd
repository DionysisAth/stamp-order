class_name StampDef
extends RefCounted
## One stamp: a shape mask, a colour and the placements it may be pressed at.
## A placement is {x, y, rot}: the top-left cell of its square box and a
## clockwise rotation in degrees. Rotatable stamps may be turned in 90° steps
## at any of their spots; the tray starts them at `start_rot`.

var shape := "square"
var size := 4
var color := 1
var placements: Array[Dictionary] = []
var rotatable := false
var start_rot := 0


static func from_dict(d: Dictionary) -> StampDef:
	var s := StampDef.new()
	s.shape = str(d.get("shape", "square"))
	s.size = int(d.get("size", 4))
	s.color = int(d.get("color", 1))
	for p in d.get("placements", []):
		s.placements.append({"x": int(p.get("x", 0)), "y": int(p.get("y", 0)), "rot": posmod(int(p.get("rot", 0)), 360)})
	s.rotatable = bool(d.get("rotatable", false))
	s.start_rot = posmod(int(d.get("start_rot", 0)), 360)
	return s


func to_dict() -> Dictionary:
	var d := {"shape": shape, "size": size, "color": color, "placements": placements.duplicate(true)}
	if rotatable:
		d["rotatable"] = true
		d["start_rot"] = start_rot
	return d


func spot_count() -> int:
	return placements.size()


## The rotation the tray shows before the player touches it.
func initial_rot(spot: int = 0) -> int:
	if rotatable:
		return start_rot
	return int(placements[spot]["rot"])


## Every (spot, rot) pose the player can press, as Vector2i(spot, rot).
func poses() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in placements.size():
		if rotatable:
			for r in [0, 90, 180, 270]:
				out.append(Vector2i(i, r))
		else:
			out.append(Vector2i(i, int(placements[i]["rot"])))
	return out


func origin(spot: int) -> Vector2i:
	var p: Dictionary = placements[spot]
	return Vector2i(int(p["x"]), int(p["y"]))


## Absolute canvas cells covered when pressed at `spot` with rotation `rot`.
func cells(spot: int, rot: int) -> Array[Vector2i]:
	var o := origin(spot)
	var out: Array[Vector2i] = []
	for c in Shapes.mask(shape, size, rot):
		out.append(o + c)
	return out


## Centre of the stamp's box in cell units.
func center(spot: int) -> Vector2:
	return Vector2(origin(spot)) + Vector2(size, size) * 0.5
