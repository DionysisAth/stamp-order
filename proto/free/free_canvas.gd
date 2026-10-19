class_name FreeCanvas
extends CanvasView
## The paper in prototype A: accepts stamps dragged from the tray. The ghost
## floats above the finger so it is never hidden under it.

signal hovered(type: int, cell: Vector2i)
signal dropped(type: int, cell: Vector2i)
signal hover_ended

## Stamp size (cells) per type, set by the game screen.
var type_sizes: Array = []


func cell_for(type: int, at: Vector2) -> Vector2i:
	var n: int = type_sizes[type]
	var r := paper_rect()
	var lift := (n * 0.5 + 1.5) * cell_px()
	var c := (at - Vector2(0, lift) - r.position) / cell_px() - Vector2(n, n) * 0.5
	return Vector2i(clampi(roundi(c.x), 0, BoardState.SIZE - n), clampi(roundi(c.y), 0, BoardState.SIZE - n))


func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("free_type"):
		return false
	hovered.emit(data["free_type"], cell_for(data["free_type"], at))
	return true


func _drop_data(at: Vector2, data: Variant) -> void:
	dropped.emit(data["free_type"], cell_for(data["free_type"], at))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		hover_ended.emit()
