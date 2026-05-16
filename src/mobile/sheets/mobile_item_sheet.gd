class_name MobileItemSheet
extends Control

signal comments_changed()
signal todo_payload_changed(item_id: String)
signal navigate_requested(target_kind: String, target_id: String)

const TODO_VIEW_SCENE: PackedScene = preload("res://src/mobile/sheets/mobile_todo_editor.tscn")
const COMMENT_LIST_SCENE: PackedScene = preload("res://src/mobile/sheets/mobile_item_comments.tscn")
const BACKLINKS_SCENE: PackedScene = preload("res://src/mobile/sheets/mobile_backlinks_section.tscn")

@onready var _tabs: TabContainer = %ItemTabs
@onready var _overview_tab: ScrollContainer = %OverviewTab
@onready var _overview_root: VBoxContainer = %OverviewRoot
@onready var _todo_tab: Control = %TodoTab
@onready var _todo_root: Control = %TodoRoot
@onready var _comments_tab: Control = %CommentsTab
@onready var _comments_root: Control = %CommentsRoot
@onready var _backlinks_tab: Control = %BacklinksTab
@onready var _backlinks_root: Control = %BacklinksRoot

var _project: Project = null
var _board: Board = null
var _item_dict: Dictionary = {}
var _board_view: MobileBoardView = null
var _todo_view: MobileTodoEditor = null
var _comments_view: MobileItemComments = null
var _backlinks_view: MobileBacklinksSection = null
var _applying: bool = false


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.set_tab_title(0, "Edit")
	if _tabs.get_tab_count() > 1:
		_tabs.set_tab_title(1, "Todo")
	if _tabs.get_tab_count() > 2:
		_tabs.set_tab_title(2, "Comments")
	if _tabs.get_tab_count() > 3:
		_tabs.set_tab_title(3, "Backlinks")


func bind_item(project: Project, board: Board, item_dict: Dictionary, board_view: MobileBoardView) -> void:
	_project = project
	_board = board
	_item_dict = item_dict.duplicate(true)
	_board_view = board_view
	_rebuild()


func refresh_with(board: Board, item_dict: Dictionary) -> void:
	_board = board
	_item_dict = item_dict.duplicate(true)
	_rebuild()


func computed_title() -> String:
	var type_id: String = String(_item_dict.get("type", ""))
	var payload_title: String = String(_item_dict.get("title", ""))
	if payload_title != "":
		return payload_title
	var text_field: String = String(_item_dict.get("text", ""))
	if text_field != "":
		return _truncate(text_field, 48)
	return _label_for_type(type_id)


func _rebuild() -> void:
	_rebuild_overview()
	_rebuild_todo()
	_rebuild_comments()
	_rebuild_backlinks()


func _rebuild_overview() -> void:
	for child: Node in _overview_root.get_children():
		child.queue_free()
	var type_id: String = String(_item_dict.get("type", ""))
	_overview_root.add_child(_kv_row("Type", _label_for_type(type_id)))
	if _item_dict.has("title"):
		_overview_root.add_child(_text_field_row("Title", "title", String(_item_dict["title"]), false))
	if _item_dict.has("text"):
		_overview_root.add_child(_text_field_row("Text", "text", String(_item_dict["text"]), true))
	if _item_dict.has("bbcode_text"):
		_overview_root.add_child(_text_field_row("Rich text (BBCode)", "bbcode_text", String(_item_dict["bbcode_text"]), true))
	if _item_dict.has("markdown_text"):
		_overview_root.add_child(_text_field_row("Document (Markdown)", "markdown_text", String(_item_dict["markdown_text"]), true))
	if _item_dict.has("code"):
		_overview_root.add_child(_text_field_row("Code", "code", String(_item_dict["code"]), true))
		_overview_root.add_child(_line_field_row("Language", "language", String(_item_dict.get("language", "plaintext"))))
	if _item_dict.has("latex"):
		_overview_root.add_child(_text_field_row("LaTeX", "latex", String(_item_dict["latex"]), true))
	if _item_dict.has("url"):
		_overview_root.add_child(_line_field_row("URL", "url", String(_item_dict["url"])))
	if _item_dict.has("font_size"):
		_overview_root.add_child(_int_field_row("Font size", "font_size", int(_item_dict["font_size"]), 8, 96))
	if type_id == ItemRegistry.TYPE_STICKY:
		_overview_root.add_child(_int_field_row("Color index", "color_index", int(_item_dict.get("color_index", 0)), 0, 7))
	if type_id == ItemRegistry.TYPE_PRIMITIVE:
		_overview_root.add_child(_int_field_row("Shape", "shape", int(_item_dict.get("shape", 0)), 0, 7))
	var dimensions: Vector2 = _vector_of(_item_dict, "size", Vector2.ZERO)
	if dimensions.x > 0.0 and dimensions.y > 0.0:
		_overview_root.add_child(_size_row(dimensions))
	_overview_root.add_child(_tags_row())
	_overview_root.add_child(_lock_row())
	_overview_root.add_child(_link_row())
	_overview_root.add_child(_actions_row())
	match type_id:
		ItemRegistry.TYPE_SUBPAGE:
			var child_id: String = String(_item_dict.get("target_board_id", _item_dict.get("child_board_id", "")))
			if child_id != "":
				_overview_root.add_child(_navigation_button("Open subpage", BoardItem.LINK_KIND_BOARD, child_id))
		ItemRegistry.TYPE_MAP_PAGE:
			var map_id: String = String(_item_dict.get("target_map_page_id", _item_dict.get("map_page_id", "")))
			if map_id != "":
				_overview_root.add_child(_navigation_button("Open map", BoardItem.LINK_KIND_MAP_PAGE, map_id))
		ItemRegistry.TYPE_PINBOARD:
			var pinned_board: String = String(_item_dict.get("target_board_id", ""))
			if pinned_board != "":
				_overview_root.add_child(_navigation_button("Open pinboard", BoardItem.LINK_KIND_BOARD, pinned_board))


func _rebuild_todo() -> void:
	for child: Node in _todo_root.get_children():
		child.queue_free()
	_todo_view = null
	if String(_item_dict.get("type", "")) != ItemRegistry.TYPE_TODO_LIST:
		_todo_tab.visible = false
		return
	_todo_tab.visible = true
	_todo_view = TODO_VIEW_SCENE.instantiate()
	_todo_root.add_child(_todo_view)
	_todo_view.bind(_item_dict)
	_todo_view.payload_changed.connect(_on_todo_payload_changed)


func _rebuild_comments() -> void:
	for child: Node in _comments_root.get_children():
		child.queue_free()
	_comments_view = COMMENT_LIST_SCENE.instantiate()
	_comments_root.add_child(_comments_view)
	_comments_view.bind(_project, _board, String(_item_dict.get("id", "")))
	_comments_view.comments_changed.connect(_on_comments_changed)


func _rebuild_backlinks() -> void:
	for child: Node in _backlinks_root.get_children():
		child.queue_free()
	_backlinks_view = BACKLINKS_SCENE.instantiate()
	_backlinks_root.add_child(_backlinks_view)
	_backlinks_view.bind(_item_dict)
	_backlinks_view.navigate_to_backlink.connect(_on_backlink_navigate)


func _on_backlink_navigate(board_id: String, item_id: String) -> void:
	if board_id == "":
		return
	if item_id != "":
		navigate_requested.emit(BoardItem.LINK_KIND_ITEM, item_id)
	else:
		navigate_requested.emit(BoardItem.LINK_KIND_BOARD, board_id)


func _on_todo_payload_changed(new_dict: Dictionary) -> void:
	_item_dict = new_dict.duplicate(true)
	if _board_view == null:
		return
	if not _board_view.update_item_payload(String(_item_dict.get("id", "")), _item_dict):
		return
	todo_payload_changed.emit(String(_item_dict.get("id", "")))


func _on_comments_changed() -> void:
	if _board_view == null or _board == null:
		return
	var aggregated: Array = _comments_view.full_board_comments()
	if _board_view.update_board_comments(aggregated):
		comments_changed.emit()


func _navigation_button(label_text: String, kind: String, target_id: String) -> Button:
	var b: Button = Button.new()
	b.text = label_text
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(func() -> void: navigate_requested.emit(kind, target_id))
	return b


func _kv_row(label_text: String, value_text: String) -> Control:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var caption: Label = Label.new()
	caption.text = label_text
	caption.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
	caption.add_theme_font_size_override("font_size", 12)
	row.add_child(caption)
	var value: Label = Label.new()
	value.text = value_text
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(value)
	return row


func _text_field_row(label_text: String, payload_key: String, value_text: String, multiline: bool) -> Control:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var caption: Label = Label.new()
	caption.text = label_text
	caption.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
	caption.add_theme_font_size_override("font_size", 12)
	row.add_child(caption)
	if multiline:
		var text_edit: TextEdit = TextEdit.new()
		text_edit.text = value_text
		text_edit.custom_minimum_size = Vector2(0, 120)
		text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		text_edit.text_changed.connect(func() -> void: _apply_payload_field(payload_key, text_edit.text))
		row.add_child(text_edit)
	else:
		var line_edit: LineEdit = LineEdit.new()
		line_edit.text = value_text
		line_edit.custom_minimum_size = Vector2(0, 40)
		line_edit.text_submitted.connect(func(t: String) -> void: _apply_payload_field(payload_key, t))
		line_edit.focus_exited.connect(func() -> void: _apply_payload_field(payload_key, line_edit.text))
		row.add_child(line_edit)
	return row


func _line_field_row(label_text: String, payload_key: String, value_text: String) -> Control:
	return _text_field_row(label_text, payload_key, value_text, false)


func _int_field_row(label_text: String, payload_key: String, value: int, min_v: int, max_v: int) -> Control:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var caption: Label = Label.new()
	caption.text = label_text
	caption.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
	caption.add_theme_font_size_override("font_size", 12)
	row.add_child(caption)
	var spin: SpinBox = SpinBox.new()
	spin.min_value = float(min_v)
	spin.max_value = float(max_v)
	spin.step = 1.0
	spin.value = float(value)
	spin.custom_minimum_size = Vector2(0, 40)
	spin.value_changed.connect(func(v: float) -> void: _apply_payload_field(payload_key, int(v)))
	row.add_child(spin)
	return row


func _size_row(dimensions: Vector2) -> Control:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var caption: Label = Label.new()
	caption.text = "Size"
	caption.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
	caption.add_theme_font_size_override("font_size", 12)
	row.add_child(caption)
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)
	var w: SpinBox = SpinBox.new()
	w.min_value = 32.0
	w.max_value = 4096.0
	w.step = 1.0
	w.value = dimensions.x
	w.custom_minimum_size = Vector2(120, 40)
	hbox.add_child(w)
	var h: SpinBox = SpinBox.new()
	h.min_value = 32.0
	h.max_value = 4096.0
	h.step = 1.0
	h.value = dimensions.y
	h.custom_minimum_size = Vector2(120, 40)
	hbox.add_child(h)
	var apply: Button = Button.new()
	apply.text = "Apply size"
	apply.custom_minimum_size = Vector2(0, 40)
	apply.pressed.connect(func() -> void: _apply_size(Vector2(w.value, h.value)))
	hbox.add_child(apply)
	return row


func _tags_row() -> Control:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var caption: Label = Label.new()
	caption.text = "Tags (comma-separated)"
	caption.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
	caption.add_theme_font_size_override("font_size", 12)
	row.add_child(caption)
	var tags_raw: Variant = _item_dict.get("tags", null)
	var current: String = ""
	if typeof(tags_raw) == TYPE_ARRAY:
		var arr: Array = tags_raw
		var pieces: PackedStringArray = PackedStringArray()
		for t in arr:
			pieces.append(String(t))
		current = ", ".join(pieces)
	var line: LineEdit = LineEdit.new()
	line.text = current
	line.placeholder_text = "tag1, tag2"
	line.custom_minimum_size = Vector2(0, 40)
	line.text_submitted.connect(func(t: String) -> void: _apply_tags(t))
	line.focus_exited.connect(func() -> void: _apply_tags(line.text))
	row.add_child(line)
	return row


func _lock_row() -> Control:
	var locked: bool = bool(_item_dict.get("locked", false))
	var check: CheckBox = CheckBox.new()
	check.text = "Locked"
	check.button_pressed = locked
	check.toggled.connect(func(p: bool) -> void: _apply_property("locked", p))
	return check


func _link_row() -> Control:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var caption: Label = Label.new()
	caption.text = "Link target"
	caption.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
	caption.add_theme_font_size_override("font_size", 12)
	row.add_child(caption)
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)
	var kind_options: OptionButton = OptionButton.new()
	kind_options.add_item("None", 0)
	kind_options.add_item("Board", 1)
	kind_options.add_item("Map page", 2)
	kind_options.add_item("Item", 3)
	var lt: Dictionary = _item_dict.get("link_target", {}) if typeof(_item_dict.get("link_target", {})) == TYPE_DICTIONARY else {}
	var current_kind: String = String(lt.get("kind", ""))
	match current_kind:
		BoardItem.LINK_KIND_BOARD:
			kind_options.select(1)
		BoardItem.LINK_KIND_MAP_PAGE:
			kind_options.select(2)
		BoardItem.LINK_KIND_ITEM:
			kind_options.select(3)
		_:
			kind_options.select(0)
	kind_options.custom_minimum_size = Vector2(140, 40)
	hbox.add_child(kind_options)
	var id_edit: LineEdit = LineEdit.new()
	id_edit.text = String(lt.get("id", ""))
	id_edit.placeholder_text = "Target id"
	id_edit.custom_minimum_size = Vector2(180, 40)
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(id_edit)
	var apply: Button = Button.new()
	apply.text = "Apply"
	apply.custom_minimum_size = Vector2(0, 40)
	apply.pressed.connect(func() -> void: _apply_link(kind_options.get_selected_id(), id_edit.text))
	hbox.add_child(apply)
	return row


func _actions_row() -> Control:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var duplicate_btn: Button = Button.new()
	duplicate_btn.text = "Duplicate"
	duplicate_btn.custom_minimum_size = Vector2(0, 48)
	duplicate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duplicate_btn.pressed.connect(_on_duplicate_pressed)
	hbox.add_child(duplicate_btn)
	var delete_btn: Button = Button.new()
	delete_btn.text = "Delete"
	delete_btn.custom_minimum_size = Vector2(0, 48)
	delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_btn.pressed.connect(_on_delete_pressed)
	hbox.add_child(delete_btn)
	return hbox


func _apply_payload_field(key: String, value: Variant) -> void:
	if _applying or _board_view == null:
		return
	_item_dict[key] = value
	_persist_item_dict()


func _apply_property(key: String, value: Variant) -> void:
	if _applying or _board_view == null:
		return
	var item_id: String = String(_item_dict.get("id", ""))
	if item_id == "":
		return
	_board_view.set_property_for_item(item_id, key, value)
	var refreshed: Dictionary = _board_view.find_item_dict(item_id)
	if not refreshed.is_empty():
		_item_dict = refreshed


func _apply_size(new_size: Vector2) -> void:
	if _applying or _board_view == null:
		return
	var item_id: String = String(_item_dict.get("id", ""))
	if item_id == "":
		return
	_board_view.set_property_for_item(item_id, "size", [new_size.x, new_size.y])
	var refreshed: Dictionary = _board_view.find_item_dict(item_id)
	if not refreshed.is_empty():
		_item_dict = refreshed


func _apply_tags(text: String) -> void:
	var raw_pieces: Array = text.split(",")
	var arr: Array = []
	for piece_v: Variant in raw_pieces:
		var trimmed: String = String(piece_v).strip_edges()
		if trimmed != "":
			arr.append(trimmed)
	_apply_property("tags", arr)


func _apply_link(option_id: int, id_text: String) -> void:
	var item_id: String = String(_item_dict.get("id", ""))
	if item_id == "" or _board_view == null:
		return
	var lt: Dictionary = {}
	match option_id:
		1:
			lt = {"kind": BoardItem.LINK_KIND_BOARD, "id": id_text.strip_edges()}
		2:
			lt = {"kind": BoardItem.LINK_KIND_MAP_PAGE, "id": id_text.strip_edges()}
		3:
			lt = {"kind": BoardItem.LINK_KIND_ITEM, "id": id_text.strip_edges()}
		_:
			lt = {}
	_apply_property("link_target", lt)


func _on_duplicate_pressed() -> void:
	var item_id: String = String(_item_dict.get("id", ""))
	if item_id == "" or _board_view == null:
		return
	var node: BoardItem = _board_view.find_item_node(item_id)
	if node == null:
		return
	var d: Dictionary = node.duplicate_dict()
	var pos: Vector2 = _vector_of(d, "position", Vector2.ZERO) + Vector2(28.0, 28.0)
	d["position"] = [pos.x, pos.y]
	History.push(AddItemsCommand.new(_board_view, [d]))


func _on_delete_pressed() -> void:
	var item_id: String = String(_item_dict.get("id", ""))
	if item_id == "" or _board_view == null:
		return
	var node: BoardItem = _board_view.find_item_node(item_id)
	if node == null:
		return
	History.push(RemoveItemsCommand.new(_board_view, [node]))


func _persist_item_dict() -> void:
	var item_id: String = String(_item_dict.get("id", ""))
	if item_id == "" or _board_view == null:
		return
	_board_view.update_item_payload(item_id, _item_dict)


func _label_for_type(type_id: String) -> String:
	match type_id:
		ItemRegistry.TYPE_TEXT: return "Text"
		ItemRegistry.TYPE_LABEL: return "Label"
		ItemRegistry.TYPE_RICH_TEXT: return "Rich text"
		ItemRegistry.TYPE_DOCUMENT: return "Document"
		ItemRegistry.TYPE_CODE: return "Code"
		ItemRegistry.TYPE_TABLE: return "Table"
		ItemRegistry.TYPE_EQUATION: return "Equation"
		ItemRegistry.TYPE_IMAGE: return "Image"
		ItemRegistry.TYPE_SOUND: return "Sound"
		ItemRegistry.TYPE_TIMER: return "Timer"
		ItemRegistry.TYPE_PRIMITIVE: return "Primitive"
		ItemRegistry.TYPE_GROUP: return "Group"
		ItemRegistry.TYPE_STICKY: return "Sticky note"
		ItemRegistry.TYPE_SUBPAGE: return "Subpage"
		ItemRegistry.TYPE_PINBOARD: return "Pinboard"
		ItemRegistry.TYPE_MAP_PAGE: return "Map page"
		ItemRegistry.TYPE_TODO_LIST: return "Todo list"
		ItemRegistry.TYPE_BLOCK_STACK: return "Block stack"
		ItemRegistry.TYPE_URL: return "URL"
		_: return type_id.capitalize() if type_id != "" else "Item"


func _vector_of(d: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var raw: Variant = d.get(key, null)
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 2:
		return Vector2(float((raw as Array)[0]), float((raw as Array)[1]))
	return fallback


func _truncate(text: String, max_length: int) -> String:
	if text.length() <= max_length:
		return text
	return text.substr(0, max_length - 1) + "…"
