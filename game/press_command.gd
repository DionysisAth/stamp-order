class_name PressCommand
extends Command
## Presses one stamp onto the board. Undo restores the canvas snapshot taken
## just before the press (256 bytes, so snapshots are cheaper than diffs).

var board: BoardState
var presses: Array
var stamp_index: int
var spot: int
var rot: int
var _stamp: StampDef
var _before := PackedByteArray()


func _init(p_board: BoardState, p_presses: Array, p_stamp: StampDef, p_index: int, p_spot: int, p_rot: int) -> void:
	board = p_board
	presses = p_presses
	_stamp = p_stamp
	stamp_index = p_index
	spot = p_spot
	rot = p_rot


func do() -> void:
	_before = board.cells.duplicate()
	board.press(_stamp, spot, rot)
	presses.append([stamp_index, spot, rot])


func undo() -> void:
	board.cells = _before.duplicate()
	presses.pop_back()
