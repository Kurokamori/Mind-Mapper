extends Node

signal project_opened(project: Project)
signal project_closed()
signal current_board_changed(board: Board)
signal navigation_changed()
signal before_navigation()
signal board_modified(board_id: String)

var current_project: Project = null
var current_board: Board = null
var nav_history: Array[String] = []


func open_project(project: Project) -> void:
	current_project = project
	nav_history.clear()
	if project != null and project.root_board_id != "":
		current_board = project.read_board(project.root_board_id)
	emit_signal("project_opened", project)
	if current_board != null:
		emit_signal("current_board_changed", current_board)
		emit_signal("navigation_changed")


func close_project() -> void:
	current_project = null
	current_board = null
	nav_history.clear()
	History.clear()
	emit_signal("project_closed")
	emit_signal("navigation_changed")


func navigate_to_board(board_id: String) -> bool:
	if current_project == null or board_id == "":
		return false
	if current_board != null and current_board.id == board_id:
		return false
	var b := current_project.read_board(board_id)
	if b == null:
		return false
	emit_signal("before_navigation")
	if current_board != null:
		nav_history.append(current_board.id)
	current_board = b
	History.clear()
	emit_signal("current_board_changed", current_board)
	emit_signal("navigation_changed")
	return true


func navigate_back() -> bool:
	if current_project == null:
		return false
	while not nav_history.is_empty():
		var prev_id: String = nav_history.pop_back()
		var prev := current_project.read_board(prev_id)
		if prev != null:
			emit_signal("before_navigation")
			current_board = prev
			History.clear()
			emit_signal("current_board_changed", current_board)
			emit_signal("navigation_changed")
			return true
	return false


func switch_board(board_id: String) -> void:
	navigate_to_board(board_id)


func breadcrumb_path() -> Array:
	var path: Array = []
	if current_project == null or current_board == null:
		return path
	var visited: Dictionary = {}
	var b: Board = current_board
	while b != null and not visited.has(b.id):
		visited[b.id] = true
		path.push_front({"id": b.id, "name": b.name})
		if b.parent_board_id == "":
			break
		b = current_project.read_board(b.parent_board_id)
	return path


func can_go_back() -> bool:
	return not nav_history.is_empty()


func save_current_board(items_dicts: Array, connection_dicts: Array = []) -> Error:
	if current_project == null or current_board == null:
		return ERR_UNCONFIGURED
	current_board.items = items_dicts.duplicate(true)
	current_board.connections = connection_dicts.duplicate(true)
	var err: Error = current_project.write_board(current_board)
	if err == OK:
		emit_signal("board_modified", current_board.id)
	return err


func write_board(board: Board) -> Error:
	if current_project == null or board == null:
		return ERR_UNCONFIGURED
	var err: Error = current_project.write_board(board)
	if err == OK:
		emit_signal("board_modified", board.id)
	return err
