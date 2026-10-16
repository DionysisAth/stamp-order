class_name UndoStack
extends RefCounted
## Unlimited, free undo. Restart is just clear() plus resetting the state.

signal changed

var _done: Array[Command] = []


func push(cmd: Command) -> void:
	cmd.do()
	_done.append(cmd)
	changed.emit()


func undo() -> bool:
	if _done.is_empty():
		return false
	var cmd: Command = _done.pop_back()
	cmd.undo()
	changed.emit()
	return true


func can_undo() -> bool:
	return not _done.is_empty()


func size() -> int:
	return _done.size()


func clear() -> void:
	_done.clear()
	changed.emit()
