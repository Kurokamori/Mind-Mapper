extends Node

signal changed()

const MAX_DEPTH := 200

var _undo_stack: Array = []
var _redo_stack: Array = []


func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	emit_signal("changed")


func push(command: HistoryCommand) -> void:
	if command == null:
		return
	command.do()
	_undo_stack.append(command)
	if _undo_stack.size() > MAX_DEPTH:
		_undo_stack.pop_front()
	_redo_stack.clear()
	emit_signal("changed")


func push_already_done(command: HistoryCommand) -> void:
	if command == null:
		return
	_undo_stack.append(command)
	if _undo_stack.size() > MAX_DEPTH:
		_undo_stack.pop_front()
	_redo_stack.clear()
	emit_signal("changed")


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func undo() -> void:
	if _undo_stack.is_empty():
		return
	var cmd: HistoryCommand = _undo_stack.pop_back()
	cmd.undo()
	_redo_stack.append(cmd)
	emit_signal("changed")


func redo() -> void:
	if _redo_stack.is_empty():
		return
	var cmd: HistoryCommand = _redo_stack.pop_back()
	cmd.do()
	_undo_stack.append(cmd)
	emit_signal("changed")
