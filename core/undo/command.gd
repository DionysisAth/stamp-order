class_name Command
extends RefCounted
## One undoable player action. Only commands change game state, so every
## move can be undone.


func do() -> void:
	pass


func undo() -> void:
	pass
