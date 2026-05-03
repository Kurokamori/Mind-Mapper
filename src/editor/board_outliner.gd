class_name BoardOutliner
extends PanelContainer

const CTX_NEW_CHILD: int = 1
const CTX_RENAME: int = 2
const CTX_DELETE: int = 3

@onready var _tree: Tree = %Tree
@onready var _new_root_button: Button = %NewRootButton
@onready var _context_menu: PopupMenu = %ContextMenu

var _items_by_board_id: Dictionary = {}
var _suppress_select_navigation: bool = false
var _context_target_board_id: String = ""
var _editing_board_id: String = ""
var _suppress_collapse_persist: bool = false


func _ready() -> void:
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_edited.connect(_on_item_edited)
	_tree.item_mouse_selected.connect(_on_item_mouse_selected)
	_tree.empty_clicked.connect(_on_empty_clicked)
	_tree.item_collapsed.connect(_on_item_collapsed)
	_tree.set_drag_forwarding(_outliner_get_drag_data, _outliner_can_drop_data, _outliner_drop_data)
	_new_root_button.pressed.connect(_on_new_root_pressed)
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	ProjectIndex.index_changed.connect(_rebuild)
	AppState.current_board_changed.connect(_on_current_board_changed)
	AppState.project_opened.connect(_on_project_opened)
	AppState.project_closed.connect(_on_project_closed)
	_rebuild()


func _on_project_opened(_p: Project) -> void:
	_rebuild()


func _on_project_closed() -> void:
	_rebuild()


func _on_current_board_changed(_b: Board) -> void:
	_highlight_current()


func _rebuild() -> void:
	if _tree == null:
		return
	_suppress_collapse_persist = true
	_items_by_board_id.clear()
	_tree.clear()
	if AppState.current_project == null:
		_suppress_collapse_persist = false
		return
	var root: TreeItem = _tree.create_item()
	root.set_text(0, "Project")
	var entries: Array = ProjectIndex.list_boards_with_parents()
	if entries.is_empty():
		var fallback: Array = AppState.current_project.list_boards()
		for entry_v: Variant in fallback:
			var entry: Dictionary = entry_v
			var bid: String = String(entry.get("id", ""))
			if bid == "":
				continue
			var b: Board = AppState.current_project.read_board(bid)
			entries.append({
				"id": bid,
				"name": String(entry.get("name", "")),
				"parent_board_id": (b.parent_board_id if b != null else ""),
			})
	var by_parent: Dictionary = {}
	for entry_v: Variant in entries:
		var entry: Dictionary = entry_v
		var pid: String = String(entry.get("parent_board_id", ""))
		if not by_parent.has(pid):
			by_parent[pid] = []
		(by_parent[pid] as Array).append(entry)
	for parent_id: String in by_parent.keys():
		(by_parent[parent_id] as Array).sort_custom(func(a, b): return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0)
	var root_board_id: String = AppState.current_project.root_board_id
	var root_entries: Array = by_parent.get("", [])
	for entry_v: Variant in root_entries:
		_insert_board(entry_v, root, by_parent, root_board_id)
	for parent_id: String in by_parent.keys():
		if parent_id == "":
			continue
		if not _items_by_board_id.has(parent_id):
			for orphan_v: Variant in (by_parent[parent_id] as Array):
				_insert_board(orphan_v, root, by_parent, root_board_id)
	_highlight_current()
	_suppress_collapse_persist = false


func _insert_board(entry_v: Variant, parent_item: TreeItem, by_parent: Dictionary, root_board_id: String) -> void:
	if typeof(entry_v) != TYPE_DICTIONARY:
		return
	var entry: Dictionary = entry_v
	var bid: String = String(entry.get("id", ""))
	if bid == "" or _items_by_board_id.has(bid):
		return
	var ti: TreeItem = _tree.create_item(parent_item)
	var label: String = String(entry.get("name", ""))
	if bid == root_board_id:
		label = "%s  (root)" % label
	ti.set_text(0, label)
	ti.set_metadata(0, bid)
	ti.set_editable(0, false)
	_items_by_board_id[bid] = ti
	var children: Array = by_parent.get(bid, [])
	for child_v: Variant in children:
		_insert_board(child_v, ti, by_parent, root_board_id)
	if AppState.current_project != null and not children.is_empty():
		ti.collapsed = UserPrefs.is_board_collapsed(AppState.current_project.id, bid)


func _highlight_current() -> void:
	if AppState.current_board == null:
		return
	var ti: TreeItem = _items_by_board_id.get(AppState.current_board.id, null) as TreeItem
	if ti == null:
		return
	_suppress_select_navigation = true
	ti.select(0)
	_tree.scroll_to_item(ti)
	_suppress_select_navigation = false


func _selected_board_id() -> String:
	var sel: TreeItem = _tree.get_selected()
	if sel == null:
		return ""
	var meta: Variant = sel.get_metadata(0)
	if typeof(meta) != TYPE_STRING:
		return ""
	return String(meta)


func _on_item_selected() -> void:
	if _suppress_select_navigation:
		return
	if _editing_board_id != "":
		return
	var bid: String = _selected_board_id()
	if bid == "" or AppState.current_board == null:
		return
	if AppState.current_board.id == bid:
		return
	AppState.navigate_to_board(bid)


func _find_entry(board_id: String) -> Dictionary:
	if AppState.current_project == null:
		return {}
	for entry_v: Variant in ProjectIndex.list_boards_with_parents():
		var entry: Dictionary = entry_v
		if String(entry.get("id", "")) == board_id:
			return entry
	if AppState.current_project.board_index.has(board_id):
		return {
			"id": board_id,
			"name": String(AppState.current_project.board_index[board_id]),
			"parent_board_id": "",
		}
	return {}


func _on_item_edited() -> void:
	var bid: String = _editing_board_id
	_editing_board_id = ""
	if bid == "":
		return
	var ti: TreeItem = _items_by_board_id.get(bid, null) as TreeItem
	if ti == null:
		return
	ti.set_editable(0, false)
	var new_name: String = ti.get_text(0).strip_edges()
	if new_name == "":
		_rebuild()
		return
	if AppState.current_project == null:
		return
	if AppState.current_project.rename_board(bid, new_name):
		AppState.emit_signal("board_modified", bid)
		if AppState.current_board != null and AppState.current_board.id == bid:
			AppState.current_board.name = new_name
			AppState.emit_signal("navigation_changed")
	else:
		_rebuild()


func _on_item_mouse_selected(_pos: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return
	var bid: String = _selected_board_id()
	if bid == "":
		return
	_open_context_menu(bid)


func _on_empty_clicked(_pos: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return
	_context_target_board_id = ""
	_context_menu.clear()
	_context_menu.add_item("New top-level board", CTX_NEW_CHILD)
	_show_context_menu_at_mouse()


func _open_context_menu(board_id: String) -> void:
	_context_target_board_id = board_id
	_context_menu.clear()
	_context_menu.add_item("New child board", CTX_NEW_CHILD)
	_context_menu.add_item("Rename", CTX_RENAME)
	_context_menu.add_separator()
	_context_menu.add_item("Delete", CTX_DELETE)
	if AppState.current_project != null and board_id == AppState.current_project.root_board_id:
		var idx: int = _context_menu.get_item_index(CTX_DELETE)
		if idx >= 0:
			_context_menu.set_item_disabled(idx, true)
	_show_context_menu_at_mouse()


func _show_context_menu_at_mouse() -> void:
	_context_menu.position = DisplayServer.mouse_get_position()
	_context_menu.reset_size()
	_context_menu.popup()


func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		CTX_NEW_CHILD:
			_create_child(_context_target_board_id)
		CTX_RENAME:
			_begin_rename(_context_target_board_id)
		CTX_DELETE:
			_delete_board(_context_target_board_id)


func _on_new_root_pressed() -> void:
	_create_child("")


func _create_child(parent_board_id: String) -> void:
	if AppState.current_project == null:
		return
	var b: Board = AppState.current_project.create_child_board(parent_board_id, "New Board")
	if b == null:
		return
	AppState.emit_signal("board_modified", b.id)
	AppState.navigate_to_board(b.id)


func _begin_rename(board_id: String) -> void:
	var ti: TreeItem = _items_by_board_id.get(board_id, null) as TreeItem
	if ti == null:
		return
	_editing_board_id = board_id
	_suppress_select_navigation = true
	ti.select(0)
	_suppress_select_navigation = false
	var entry: Dictionary = _find_entry(board_id)
	ti.set_text(0, String(entry.get("name", "")))
	ti.set_editable(0, true)
	_tree.edit_selected()


func _on_item_collapsed(item: TreeItem) -> void:
	if _suppress_collapse_persist or item == null:
		return
	if AppState.current_project == null:
		return
	var meta: Variant = item.get_metadata(0)
	if typeof(meta) != TYPE_STRING:
		return
	var bid: String = String(meta)
	if bid == "":
		return
	UserPrefs.set_board_collapsed(AppState.current_project.id, bid, item.collapsed)


func _outliner_get_drag_data(_at_position: Vector2) -> Variant:
	if AppState.current_project == null:
		return null
	var ti: TreeItem = _tree.get_selected()
	if ti == null:
		return null
	var meta: Variant = ti.get_metadata(0)
	if typeof(meta) != TYPE_STRING:
		return null
	var bid: String = String(meta)
	if bid == "" or bid == AppState.current_project.root_board_id:
		return null
	var preview: Label = Label.new()
	preview.text = "  ⇆  %s" % ti.get_text(0)
	preview.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	_tree.set_drag_preview(preview)
	return {"source": "board_outliner", "board_id": bid}


func _outliner_can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if String((data as Dictionary).get("source", "")) != "board_outliner":
		return false
	if AppState.current_project == null:
		return false
	var src_id: String = String((data as Dictionary).get("board_id", ""))
	if src_id == "" or src_id == AppState.current_project.root_board_id:
		return false
	var target_id: String = _drop_target_board_id(_at_position)
	if target_id == src_id:
		return false
	if target_id != "" and AppState.current_project.is_descendant(target_id, src_id):
		return false
	return true


func _outliner_drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	if AppState.current_project == null:
		return
	var src_id: String = String((data as Dictionary).get("board_id", ""))
	if src_id == "":
		return
	var target_id: String = _drop_target_board_id(_at_position)
	var current_board: Board = AppState.current_project.read_board(src_id)
	if current_board == null:
		return
	if current_board.parent_board_id == target_id:
		return
	if not AppState.current_project.reparent_board(src_id, target_id):
		return
	AppState.emit_signal("board_modified", src_id)


func _drop_target_board_id(at_position: Vector2) -> String:
	var ti: TreeItem = _tree.get_item_at_position(at_position)
	if ti == null:
		return ""
	var meta: Variant = ti.get_metadata(0)
	if typeof(meta) != TYPE_STRING:
		return ""
	return String(meta)


func _delete_board(board_id: String) -> void:
	if AppState.current_project == null or board_id == "":
		return
	if board_id == AppState.current_project.root_board_id:
		return
	var current_b: Board = AppState.current_project.read_board(board_id)
	var parent_id: String = ""
	if current_b != null:
		parent_id = current_b.parent_board_id
	if not AppState.current_project.delete_board(board_id):
		return
	if AppState.current_board != null and AppState.current_board.id == board_id:
		var fallback: String = parent_id if parent_id != "" else AppState.current_project.root_board_id
		if fallback != "":
			AppState.navigate_to_board(fallback)
	AppState.emit_signal("board_modified", board_id)
