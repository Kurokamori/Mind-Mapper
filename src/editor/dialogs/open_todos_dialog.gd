extends Window

@onready var _tree: Tree = %Tree
@onready var _close_btn: Button = %CloseButton
@onready var _refresh_btn: Button = %RefreshButton
@onready var _status: Label = %StatusLabel

var _editor: Node = null


func bind(editor: Node) -> void:
	_editor = editor


func _ready() -> void:
	close_requested.connect(queue_free)
	_close_btn.pressed.connect(queue_free)
	_refresh_btn.pressed.connect(_refresh)
	_tree.item_activated.connect(_on_item_activated)
	_refresh()


func _refresh() -> void:
	_tree.clear()
	if AppState.current_project == null:
		_status.text = "(no project)"
		return
	_tree.columns = 4
	_tree.set_column_titles_visible(true)
	_tree.set_column_title(0, "Task")
	_tree.set_column_title(1, "Priority")
	_tree.set_column_title(2, "Due")
	_tree.set_column_title(3, "Board")
	var root: TreeItem = _tree.create_item()
	var total: int = 0
	for entry in AppState.current_project.list_boards():
		var b: Board = AppState.current_project.read_board(String(entry.id))
		if b == null:
			continue
		for d_v in b.items:
			if typeof(d_v) != TYPE_DICTIONARY:
				continue
			var d: Dictionary = d_v
			if String(d.get("type", "")) != ItemRegistry.TYPE_TODO_LIST:
				continue
			var cards: Variant = d.get("cards", [])
			if typeof(cards) != TYPE_ARRAY:
				continue
			for c_v in (cards as Array):
				if typeof(c_v) != TYPE_DICTIONARY:
					continue
				var card: Dictionary = c_v
				if bool(card.get("completed", false)):
					continue
				var item: TreeItem = _tree.create_item(root)
				item.set_text(0, String(card.get("text", "")))
				item.set_text(1, _priority_label(int(card.get("priority", 0))))
				var due_unix: int = int(card.get("due_unix", 0))
				if due_unix > 0:
					item.set_text(2, Time.get_date_string_from_unix_time(due_unix))
					if due_unix < int(Time.get_unix_time_from_system()):
						item.set_custom_color(2, Color(1.0, 0.45, 0.45))
				else:
					item.set_text(2, "")
				item.set_text(3, String(b.name))
				item.set_metadata(0, {"board_id": b.id, "item_id": String(d.get("id", "")), "card_id": String(card.get("id", ""))})
				total += 1
	_status.text = "%d open tasks" % total


func _priority_label(p: int) -> String:
	match p:
		3: return "🔴 High"
		2: return "🟡 Medium"
		1: return "🟢 Low"
	return ""


func _on_item_activated() -> void:
	var sel: TreeItem = _tree.get_selected()
	if sel == null or _editor == null:
		return
	var meta: Variant = sel.get_metadata(0)
	if typeof(meta) != TYPE_DICTIONARY:
		return
	if _editor.has_method("navigate_to_backlink"):
		_editor.navigate_to_backlink(String(meta.get("board_id", "")), String(meta.get("item_id", "")))
	queue_free()
