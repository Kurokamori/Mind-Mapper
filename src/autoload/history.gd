extends Node

signal changed()

const MAX_DEPTH: int = 200

var _project: Project = null
var _bound_board_id: String = ""
var _per_board_undo: Dictionary = {}
var _per_board_redo: Dictionary = {}


func set_project(project: Project) -> void:
	_project = project


func clear_all() -> void:
	_per_board_undo.clear()
	_per_board_redo.clear()
	_bound_board_id = ""
	emit_signal("changed")


func bind_board(board_id: String) -> void:
	_bound_board_id = board_id
	if not _per_board_undo.has(board_id):
		_per_board_undo[board_id] = []
	if not _per_board_redo.has(board_id):
		_per_board_redo[board_id] = []
	emit_signal("changed")


func clear_for_board(board_id: String) -> void:
	if _per_board_undo.has(board_id):
		_per_board_undo[board_id] = []
	if _per_board_redo.has(board_id):
		_per_board_redo[board_id] = []
	if board_id == _bound_board_id:
		emit_signal("changed")


func clear() -> void:
	if _bound_board_id == "":
		return
	clear_for_board(_bound_board_id)


func push(command: HistoryCommand) -> void:
	if command == null or _bound_board_id == "":
		if command != null:
			command.do()
		return
	command.do()
	var undo_stack: Array = _per_board_undo.get(_bound_board_id, [])
	undo_stack.append(command)
	if undo_stack.size() > MAX_DEPTH:
		undo_stack.pop_front()
	_per_board_undo[_bound_board_id] = undo_stack
	_per_board_redo[_bound_board_id] = []
	emit_signal("changed")


func push_already_done(command: HistoryCommand) -> void:
	if command == null or _bound_board_id == "":
		return
	var undo_stack: Array = _per_board_undo.get(_bound_board_id, [])
	undo_stack.append(command)
	if undo_stack.size() > MAX_DEPTH:
		undo_stack.pop_front()
	_per_board_undo[_bound_board_id] = undo_stack
	_per_board_redo[_bound_board_id] = []
	emit_signal("changed")


func can_undo() -> bool:
	if _bound_board_id == "":
		return false
	var undo_stack: Array = _per_board_undo.get(_bound_board_id, [])
	return not undo_stack.is_empty()


func can_redo() -> bool:
	if _bound_board_id == "":
		return false
	var redo_stack: Array = _per_board_redo.get(_bound_board_id, [])
	return not redo_stack.is_empty()


func undo() -> void:
	if _bound_board_id == "":
		return
	var undo_stack: Array = _per_board_undo.get(_bound_board_id, [])
	if undo_stack.is_empty():
		return
	var cmd: HistoryCommand = undo_stack.pop_back()
	cmd.undo()
	var redo_stack: Array = _per_board_redo.get(_bound_board_id, [])
	redo_stack.append(cmd)
	_per_board_undo[_bound_board_id] = undo_stack
	_per_board_redo[_bound_board_id] = redo_stack
	emit_signal("changed")


func redo() -> void:
	if _bound_board_id == "":
		return
	var redo_stack: Array = _per_board_redo.get(_bound_board_id, [])
	if redo_stack.is_empty():
		return
	var cmd: HistoryCommand = redo_stack.pop_back()
	cmd.do()
	var undo_stack: Array = _per_board_undo.get(_bound_board_id, [])
	undo_stack.append(cmd)
	_per_board_undo[_bound_board_id] = undo_stack
	_per_board_redo[_bound_board_id] = redo_stack
	emit_signal("changed")
