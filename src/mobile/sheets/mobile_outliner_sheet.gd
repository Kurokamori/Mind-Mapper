class_name MobileOutlinerSheet
extends Control

signal board_chosen(board_id: String)
signal map_chosen(map_id: String)

@onready var _tree: Tree = %OutlinerTree

var _project: Project = null
var _items_by_meta: Dictionary = {}


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_item_selected)
	_tree.hide_root = false
	_tree.allow_rmb_select = false


func bind(project: Project) -> void:
	_project = project
	_rebuild()
	if not ProjectIndex.index_changed.is_connected(_rebuild):
		ProjectIndex.index_changed.connect(_rebuild)


func _exit_tree() -> void:
	if ProjectIndex.index_changed.is_connected(_rebuild):
		ProjectIndex.index_changed.disconnect(_rebuild)


func _rebuild() -> void:
	if _project == null:
		return
	_tree.clear()
	_items_by_meta.clear()
	var root: TreeItem = _tree.create_item()
	root.set_text(0, _project.name if _project != null else "Project")
	root.set_selectable(0, false)
	var entries: Array = ProjectIndex.list_boards_with_parents()
	var by_parent: Dictionary = {}
	for entry_v: Variant in entries:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var parent_id: String = String(entry.get("parent_board_id", ""))
		if not by_parent.has(parent_id):
			by_parent[parent_id] = []
		(by_parent[parent_id] as Array).append(entry)
	_add_boards_under(root, "", by_parent)
	_add_maps(root)
	root.set_collapsed_recursive(false)


func _add_boards_under(parent_item: TreeItem, parent_board_id: String, by_parent: Dictionary) -> void:
	var children_raw: Variant = by_parent.get(parent_board_id, null)
	if typeof(children_raw) != TYPE_ARRAY:
		return
	var children: Array = children_raw
	children.sort_custom(func(a: Variant, b: Variant) -> bool:
		return String((a as Dictionary).get("name", "")).naturalnocasecmp_to(String((b as Dictionary).get("name", ""))) < 0
	)
	for entry_v: Variant in children:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var board_id: String = String(entry.get("id", ""))
		var name_text: String = String(entry.get("name", ""))
		var node: TreeItem = _tree.create_item(parent_item)
		node.set_text(0, name_text)
		node.set_metadata(0, {"kind": "board", "id": board_id})
		_add_boards_under(node, board_id, by_parent)


func _add_maps(root: TreeItem) -> void:
	if _project == null:
		return
	var maps_raw: Array = _project.list_map_pages()
	if maps_raw.is_empty():
		return
	var header: TreeItem = _tree.create_item(root)
	header.set_text(0, "Maps")
	header.set_selectable(0, false)
	for entry_v: Variant in maps_raw:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var map_id: String = String(entry.get("id", ""))
		var name_text: String = String(entry.get("name", ""))
		var node: TreeItem = _tree.create_item(header)
		node.set_text(0, name_text)
		node.set_metadata(0, {"kind": "map", "id": map_id})


func _on_item_selected() -> void:
	var sel: TreeItem = _tree.get_selected()
	if sel == null:
		return
	var meta: Variant = sel.get_metadata(0)
	if typeof(meta) != TYPE_DICTIONARY:
		return
	var kind: String = String((meta as Dictionary).get("kind", ""))
	var id: String = String((meta as Dictionary).get("id", ""))
	if id == "":
		return
	if kind == "board":
		board_chosen.emit(id)
	elif kind == "map":
		map_chosen.emit(id)
