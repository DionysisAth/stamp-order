class_name BoardState
extends RefCounted
## Pure game state: the 16×16 canvas of colour ids (0 = paper). No nodes,
## so the solver, generator, tests and the game scene all share it.

const SIZE := 16

var cells := PackedByteArray()


func _init() -> void:
	cells.resize(SIZE * SIZE)
	cells.fill(0)


static func index(x: int, y: int) -> int:
	return y * SIZE + x


static func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < SIZE and c.y < SIZE


func get_at(x: int, y: int) -> int:
	return cells[index(x, y)]


## Ink is opaque: every covered cell takes the stamp's colour.
func press_cells(covered: Array[Vector2i], color_id: int) -> void:
	for c in covered:
		if in_bounds(c):
			cells[index(c.x, c.y)] = color_id


func press(stamp: StampDef, spot: int, rot: int) -> void:
	press_cells(stamp.cells(spot, rot), stamp.color)


func matches(other: BoardState) -> bool:
	return cells == other.cells


func copy() -> BoardState:
	var b := BoardState.new()
	b.cells = cells.duplicate()
	return b


func clear() -> void:
	cells.fill(0)


func count_color(color_id: int) -> int:
	return cells.count(color_id)
