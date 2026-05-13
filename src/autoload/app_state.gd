extends Node

signal project_opened(project: Project)
signal project_closed()
signal current_board_changed(board: Board)
signal current_map_page_changed(page: MapPage)
signal current_page_kind_changed(kind: String)
signal navigation_changed()
signal before_navigation()
signal board_modified(board_id: String)
signal map_page_modified(map_id: String)
signal tileset_changed(tileset_id: String)
signal save_state_changed(state: String, unix_time: int)
signal tag_filter_changed(tag: String)
signal templates_changed()

const SAVE_STATE_DIRTY: String = "dirty"
const SAVE_STATE_SAVING: String = "saving"
const SAVE_STATE_SAVED: String = "saved"

const PAGE_KIND_BOARD: String = "board"
const PAGE_KIND_MAP: String = "map"

var current_project: Project = null
var current_board: Board = null
var current_map_page: MapPage = null
var current_page_kind: String = PAGE_KIND_BOARD
var nav_history: Array = []
var save_state: String = SAVE_STATE_SAVED
var last_save_unix: int = 0
var active_tag_filter: String = ""
var _pending_nav_board_id: String = ""
var _pending_nav_map_id: String = ""


func open_project(project: Project) -> void:
	current_project = project
	nav_history.clear()
	current_map_page = null
	current_page_kind = PAGE_KIND_BOARD
	History.set_project(project)
	if project != null and project.root_board_id != "":
		current_board = project.read_board(project.root_board_id)
	_set_save_state(SAVE_STATE_SAVED, int(Time.get_unix_time_from_system()))
	emit_signal("project_opened", project)
	if current_board != null:
		History.bind_page(current_board.id)
		emit_signal("current_board_changed", current_board)
		emit_signal("current_page_kind_changed", current_page_kind)
		emit_signal("navigation_changed")


func _exit_tree() -> void:
	current_project = null
	current_board = null
	current_map_page = null
	nav_history.clear()
	active_tag_filter = ""


func close_project() -> void:
	current_project = null
	current_board = null
	current_map_page = null
	current_page_kind = PAGE_KIND_BOARD
	nav_history.clear()
	active_tag_filter = ""
	History.set_project(null)
	History.clear_all()
	emit_signal("project_closed")
	emit_signal("navigation_changed")


func navigate_to_board(board_id: String) -> bool:
	if current_project == null or board_id == "":
		return false
	if current_page_kind == PAGE_KIND_BOARD and current_board != null and current_board.id == board_id:
		return false
	var b: Board = current_project.read_board(board_id)
	if b == null:
		_pending_nav_board_id = board_id
		_request_remote_board_if_possible(board_id)
		return false
	_pending_nav_board_id = ""
	emit_signal("before_navigation")
	_push_current_to_history()
	current_board = b
	current_map_page = null
	var prev_kind: String = current_page_kind
	current_page_kind = PAGE_KIND_BOARD
	History.bind_page(board_id)
	emit_signal("current_board_changed", current_board)
	if prev_kind != current_page_kind:
		emit_signal("current_page_kind_changed", current_page_kind)
	emit_signal("navigation_changed")
	return true


func navigate_to_map_page(map_id: String) -> bool:
	if current_project == null or map_id == "":
		return false
	if current_page_kind == PAGE_KIND_MAP and current_map_page != null and current_map_page.id == map_id:
		return false
	var p: MapPage = current_project.read_map_page(map_id)
	if p == null:
		_pending_nav_map_id = map_id
		_request_remote_map_if_possible(map_id)
		return false
	_pending_nav_map_id = ""
	emit_signal("before_navigation")
	_push_current_to_history()
	current_map_page = p
	current_board = null
	var prev_kind: String = current_page_kind
	current_page_kind = PAGE_KIND_MAP
	History.bind_page(map_id)
	emit_signal("current_map_page_changed", current_map_page)
	if prev_kind != current_page_kind:
		emit_signal("current_page_kind_changed", current_page_kind)
	emit_signal("navigation_changed")
	return true


func _request_remote_map_if_possible(map_id: String) -> void:
	if map_id == "":
		return
	var root: Node = get_tree().root
	if root == null or not root.has_node("MultiplayerService"):
		return
	var mps: Node = root.get_node("MultiplayerService")
	if not mps.has_method("is_in_session") or not bool(mps.call("is_in_session")):
		return
	if mps.has_method("request_map_page"):
		mps.call("request_map_page", map_id)


func apply_remote_map_page_snapshot(page: MapPage) -> void:
	if current_project == null or page == null:
		return
	if _pending_nav_map_id == page.id:
		_pending_nav_map_id = ""
		emit_signal("before_navigation")
		_push_current_to_history()
		current_map_page = page
		current_board = null
		var prev_kind_pn: String = current_page_kind
		current_page_kind = PAGE_KIND_MAP
		History.bind_page(page.id)
		emit_signal("current_map_page_changed", current_map_page)
		if prev_kind_pn != current_page_kind:
			emit_signal("current_page_kind_changed", current_page_kind)
		emit_signal("map_page_modified", page.id)
		emit_signal("navigation_changed")
		return
	if current_page_kind == PAGE_KIND_MAP and current_map_page != null and current_map_page.id == page.id:
		current_map_page = page
		emit_signal("current_map_page_changed", current_map_page)
		emit_signal("map_page_modified", page.id)
		emit_signal("navigation_changed")
		return
	emit_signal("map_page_modified", page.id)


func notify_tileset_received(tileset_id: String) -> void:
	if tileset_id == "":
		return
	emit_signal("tileset_changed", tileset_id)


func navigate_back() -> bool:
	if current_project == null:
		return false
	while not nav_history.is_empty():
		var prev_entry_v: Variant = nav_history.pop_back()
		if typeof(prev_entry_v) != TYPE_DICTIONARY:
			continue
		var prev_entry: Dictionary = prev_entry_v
		var kind: String = String(prev_entry.get("kind", PAGE_KIND_BOARD))
		var prev_id: String = String(prev_entry.get("id", ""))
		if prev_id == "":
			continue
		if kind == PAGE_KIND_MAP:
			var page: MapPage = current_project.read_map_page(prev_id)
			if page != null:
				emit_signal("before_navigation")
				current_map_page = page
				current_board = null
				var prev_kind: String = current_page_kind
				current_page_kind = PAGE_KIND_MAP
				History.bind_page(prev_id)
				emit_signal("current_map_page_changed", current_map_page)
				if prev_kind != current_page_kind:
					emit_signal("current_page_kind_changed", current_page_kind)
				emit_signal("navigation_changed")
				return true
		else:
			var prev: Board = current_project.read_board(prev_id)
			if prev != null:
				emit_signal("before_navigation")
				current_board = prev
				current_map_page = null
				var prev_kind_b: String = current_page_kind
				current_page_kind = PAGE_KIND_BOARD
				History.bind_page(prev_id)
				emit_signal("current_board_changed", current_board)
				if prev_kind_b != current_page_kind:
					emit_signal("current_page_kind_changed", current_page_kind)
				emit_signal("navigation_changed")
				return true
	return false


func switch_board(board_id: String) -> void:
	navigate_to_board(board_id)


func _push_current_to_history() -> void:
	if current_page_kind == PAGE_KIND_BOARD and current_board != null:
		nav_history.append({"kind": PAGE_KIND_BOARD, "id": current_board.id})
	elif current_page_kind == PAGE_KIND_MAP and current_map_page != null:
		nav_history.append({"kind": PAGE_KIND_MAP, "id": current_map_page.id})


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


func mark_dirty() -> void:
	_set_save_state(SAVE_STATE_DIRTY, 0)


func mark_saving() -> void:
	_set_save_state(SAVE_STATE_SAVING, 0)


func mark_saved() -> void:
	_set_save_state(SAVE_STATE_SAVED, int(Time.get_unix_time_from_system()))


func set_tag_filter(tag: String) -> void:
	if active_tag_filter == tag:
		return
	active_tag_filter = tag
	emit_signal("tag_filter_changed", tag)


func notify_templates_changed() -> void:
	emit_signal("templates_changed")


func _set_save_state(state: String, unix_time: int) -> void:
	save_state = state
	if unix_time > 0:
		last_save_unix = unix_time
	emit_signal("save_state_changed", state, unix_time)


func save_current_board(items_dicts: Array, connection_dicts: Array = [], comment_dicts: Variant = null, annotation_dicts: Variant = null) -> Error:
	if current_project == null or current_board == null:
		return ERR_UNCONFIGURED
	mark_saving()
	current_board.items = items_dicts.duplicate(true)
	current_board.connections = connection_dicts.duplicate(true)
	if typeof(comment_dicts) == TYPE_ARRAY:
		current_board.comments = (comment_dicts as Array).duplicate(true)
	if typeof(annotation_dicts) == TYPE_ARRAY:
		current_board.annotations = (annotation_dicts as Array).duplicate(true)
	var err: Error = current_project.write_board(current_board)
	if err == OK:
		mark_saved()
		emit_signal("board_modified", current_board.id)
	else:
		mark_dirty()
	return err


func write_board(board: Board) -> Error:
	if current_project == null or board == null:
		return ERR_UNCONFIGURED
	var err: Error = current_project.write_board(board)
	if err == OK:
		emit_signal("board_modified", board.id)
	return err


func _request_remote_board_if_possible(board_id: String) -> void:
	if board_id == "":
		return
	var root: Node = get_tree().root
	if root == null or not root.has_node("MultiplayerService"):
		return
	var mps: Node = root.get_node("MultiplayerService")
	if not mps.has_method("is_in_session") or not bool(mps.call("is_in_session")):
		return
	if mps.has_method("request_board"):
		mps.call("request_board", board_id)


func apply_remote_board_snapshot(board: Board) -> void:
	if current_project == null or board == null:
		return
	if _pending_nav_board_id == board.id:
		_pending_nav_board_id = ""
		emit_signal("before_navigation")
		_push_current_to_history()
		current_board = board
		current_map_page = null
		var prev_kind_pn: String = current_page_kind
		current_page_kind = PAGE_KIND_BOARD
		History.bind_page(board.id)
		emit_signal("current_board_changed", current_board)
		if prev_kind_pn != current_page_kind:
			emit_signal("current_page_kind_changed", current_page_kind)
		emit_signal("board_modified", board.id)
		emit_signal("navigation_changed")
		return
	if current_page_kind == PAGE_KIND_BOARD and current_board != null and current_board.id == board.id:
		current_board = board
		History.bind_page(board.id)
		emit_signal("current_board_changed", current_board)
		emit_signal("board_modified", board.id)
		emit_signal("navigation_changed")
		return
	if current_board == null and current_project.root_board_id == board.id:
		current_board = board
		current_map_page = null
		var prev_kind: String = current_page_kind
		current_page_kind = PAGE_KIND_BOARD
		History.bind_page(board.id)
		emit_signal("current_board_changed", current_board)
		if prev_kind != current_page_kind:
			emit_signal("current_page_kind_changed", current_page_kind)
		emit_signal("board_modified", board.id)
		emit_signal("navigation_changed")
		return
	emit_signal("board_modified", board.id)


func save_current_map_page() -> Error:
	if current_project == null or current_map_page == null:
		return ERR_UNCONFIGURED
	mark_saving()
	var err: Error = current_project.write_map_page(current_map_page)
	if err == OK:
		mark_saved()
		emit_signal("map_page_modified", current_map_page.id)
	else:
		mark_dirty()
	return err


func write_map_page(page: MapPage) -> Error:
	if current_project == null or page == null:
		return ERR_UNCONFIGURED
	var err: Error = current_project.write_map_page(page)
	if err == OK:
		emit_signal("map_page_modified", page.id)
	return err
