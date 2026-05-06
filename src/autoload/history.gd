extends Node

signal changed()

const MAX_DEPTH: int = 200

var _project: Project = null
var _bound_page_id: String = ""
var _per_page_undo: Dictionary = {}
var _per_page_redo: Dictionary = {}


func set_project(project: Project) -> void:
	_project = project


func clear_all() -> void:
	_per_page_undo.clear()
	_per_page_redo.clear()
	_bound_page_id = ""
	emit_signal("changed")


func bind_board(board_id: String) -> void:
	bind_page(board_id)


func bind_page(page_id: String) -> void:
	_bound_page_id = page_id
	if not _per_page_undo.has(page_id):
		_per_page_undo[page_id] = []
	if not _per_page_redo.has(page_id):
		_per_page_redo[page_id] = []
	emit_signal("changed")


func clear_for_board(board_id: String) -> void:
	clear_for_page(board_id)


func clear_for_page(page_id: String) -> void:
	if _per_page_undo.has(page_id):
		_per_page_undo[page_id] = []
	if _per_page_redo.has(page_id):
		_per_page_redo[page_id] = []
	if page_id == _bound_page_id:
		emit_signal("changed")


func clear() -> void:
	if _bound_page_id == "":
		return
	clear_for_board(_bound_page_id)


func push(command: HistoryCommand) -> void:
	if command == null or _bound_page_id == "":
		if command != null:
			command.do()
		return
	command.do()
	var undo_stack: Array = _per_page_undo.get(_bound_page_id, [])
	undo_stack.append(command)
	if undo_stack.size() > MAX_DEPTH:
		undo_stack.pop_front()
	_per_page_undo[_bound_page_id] = undo_stack
	_per_page_redo[_bound_page_id] = []
	emit_signal("changed")


func push_already_done(command: HistoryCommand) -> void:
	if command == null or _bound_page_id == "":
		if command != null:
			command.record_op_forward()
		return
	command.record_op_forward()
	var undo_stack: Array = _per_page_undo.get(_bound_page_id, [])
	undo_stack.append(command)
	if undo_stack.size() > MAX_DEPTH:
		undo_stack.pop_front()
	_per_page_undo[_bound_page_id] = undo_stack
	_per_page_redo[_bound_page_id] = []
	emit_signal("changed")


func can_undo() -> bool:
	if _bound_page_id == "":
		return false
	var undo_stack: Array = _per_page_undo.get(_bound_page_id, [])
	return not undo_stack.is_empty()


func can_redo() -> bool:
	if _bound_page_id == "":
		return false
	var redo_stack: Array = _per_page_redo.get(_bound_page_id, [])
	return not redo_stack.is_empty()


func undo() -> void:
	if _bound_page_id == "":
		return
	var undo_stack: Array = _per_page_undo.get(_bound_page_id, [])
	if undo_stack.is_empty():
		return
	var cmd: HistoryCommand = undo_stack.pop_back()
	cmd.undo()
	var redo_stack: Array = _per_page_redo.get(_bound_page_id, [])
	redo_stack.append(cmd)
	_per_page_undo[_bound_page_id] = undo_stack
	_per_page_redo[_bound_page_id] = redo_stack
	emit_signal("changed")


func redo() -> void:
	if _bound_page_id == "":
		return
	var redo_stack: Array = _per_page_redo.get(_bound_page_id, [])
	if redo_stack.is_empty():
		return
	var cmd: HistoryCommand = redo_stack.pop_back()
	cmd.do()
	var undo_stack: Array = _per_page_undo.get(_bound_page_id, [])
	undo_stack.append(cmd)
	_per_page_undo[_bound_page_id] = undo_stack
	_per_page_redo[_bound_page_id] = redo_stack
	emit_signal("changed")
