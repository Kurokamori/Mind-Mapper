class_name TodoListNode
extends BoardItem

const HEADER_HEIGHT: float = 40.0
const PADDING: Vector2 = Vector2(10, 8)
const ADD_BUTTON_HEIGHT: float = 32.0
const ADD_BUTTON_BOTTOM_MARGIN: float = 10.0
const SCROLL_GAP: float = 8.0
const DARK_HEADER_BG: Color = Color(0.22, 0.34, 0.50, 1.0)
const LIGHT_HEADER_BG: Color = Color(0.55, 0.72, 0.92, 1.0)
const DARK_HEADER_FG: Color = Color(0.95, 0.97, 1.0, 1.0)
const LIGHT_HEADER_FG: Color = Color(0.06, 0.10, 0.18, 1.0)
const LEGACY_BG: Color = Color(0.13, 0.14, 0.17, 1.0)
const LEGACY_HEADER_BG: Color = DARK_HEADER_BG
const LEGACY_HEADER_FG: Color = DARK_HEADER_FG

@export var title: String = "List"
@export var bg_color: Color = Color(0, 0, 0, 1)
@export var bg_color_custom: bool = false
@export var accent_color: Color = DARK_HEADER_BG
@export var accent_color_custom: bool = false
@export var header_fg_color: Color = DARK_HEADER_FG
@export var header_fg_color_custom: bool = false
@export var cards: Array = []

@onready var _title_label: Label = %TitleLabel
@onready var _title_edit: LineEdit = %TitleEdit
@onready var _add_button: Button = %AddButton
@onready var _scroll: ScrollContainer = %CardsScroll
@onready var _cards_container: VBoxContainer = %CardsContainer
@onready var _drop_indicator: ColorRect = %DropIndicator

var _pre_edit_title: String = ""
var _drop_indicator_index: int = -1


func _ready() -> void:
	super._ready()
	ThemeManager.theme_applied.connect(_refresh_visuals)
	ThemeManager.node_palette_changed.connect(func(_a: Dictionary, _b: Dictionary) -> void: _refresh_visuals())
	_layout()
	_refresh_visuals()
	_rebuild_cards()
	if read_only:
		return
	_title_edit.focus_exited.connect(_on_edit_focus_exited)
	_title_edit.text_submitted.connect(_on_edit_submitted)
	_add_button.pressed.connect(_on_add_pressed)
	SelectionBus.selection_changed.connect(_on_selection_changed)


func resolved_bg_color() -> Color:
	return bg_color if bg_color_custom else ThemeManager.node_bg_color()


func resolved_accent_color() -> Color:
	return accent_color if accent_color_custom else ThemeManager.heading_bg("todo")


func resolved_header_fg_color() -> Color:
	return header_fg_color if header_fg_color_custom else ThemeManager.heading_fg("todo")


func default_size() -> Vector2:
	return Vector2(340, 400)


func display_name() -> String:
	return "Todo List"


func minimum_item_size() -> Vector2:
	return Vector2(260.0, HEADER_HEIGHT + ADD_BUTTON_HEIGHT + ADD_BUTTON_BOTTOM_MARGIN + SCROLL_GAP + 40.0)


func _draw_body() -> void:
	var bg: Color = resolved_bg_color()
	var accent: Color = resolved_accent_color()
	_draw_rounded_panel(bg, accent.darkened(0.3), HEADER_HEIGHT, accent)


func _layout() -> void:
	var title_y: float = (HEADER_HEIGHT - 24.0) * 0.5
	if _title_label != null:
		_title_label.position = Vector2(PADDING.x, title_y)
		_title_label.size = Vector2(size.x - PADDING.x * 2, 24.0)
	if _title_edit != null:
		_title_edit.position = Vector2(PADDING.x, title_y)
		_title_edit.size = Vector2(size.x - PADDING.x * 2, 24.0)
	if _scroll != null:
		_scroll.position = Vector2(PADDING.x, HEADER_HEIGHT + SCROLL_GAP)
		_scroll.size = Vector2(
			size.x - PADDING.x * 2,
			size.y - HEADER_HEIGHT - ADD_BUTTON_HEIGHT - ADD_BUTTON_BOTTOM_MARGIN - SCROLL_GAP * 2,
		)
	if _add_button != null:
		_add_button.position = Vector2(PADDING.x, size.y - ADD_BUTTON_HEIGHT - ADD_BUTTON_BOTTOM_MARGIN)
		_add_button.size = Vector2(size.x - PADDING.x * 2, ADD_BUTTON_HEIGHT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _refresh_visuals() -> void:
	var fg: Color = resolved_header_fg_color()
	if _title_label != null:
		_title_label.text = title
		_title_label.add_theme_color_override("font_color", fg)
	if _title_edit != null:
		_title_edit.add_theme_color_override("font_color", fg)
	queue_redraw()


func _rebuild_cards() -> void:
	if _cards_container == null:
		return
	for child in _cards_container.get_children():
		if child == _drop_indicator:
			continue
		child.queue_free()
	for card in cards:
		var row_scene: PackedScene = preload("res://src/nodes/todo_list/todo_card_row.tscn")
		var row: TodoCardRow = row_scene.instantiate()
		row.bind(item_id, card)
		row.text_changed.connect(_on_card_text_changed)
		row.completed_toggled.connect(_on_card_completed_toggled)
		row.delete_requested.connect(_on_card_delete_requested)
		row.priority_changed.connect(_on_card_priority_changed)
		row.due_changed.connect(_on_card_due_changed)
		_cards_container.add_child(row)
	_position_drop_indicator(-1)


func _on_add_pressed() -> void:
	var before: Array = cards.duplicate(true)
	var new_card: Dictionary = {
		"id": Uuid.v4(),
		"text": "",
		"completed": false,
	}
	cards.append(new_card)
	_rebuild_cards()
	_push_cards_history(before)


func _on_card_text_changed(card_id: String, new_text: String) -> void:
	for c in cards:
		if String(c.get("id", "")) == card_id:
			if String(c.get("text", "")) == new_text:
				return
			break
	var before: Array = cards.duplicate(true)
	for c in cards:
		if String(c.get("id", "")) == card_id:
			c["text"] = new_text
			break
	_push_cards_history(before)


func _on_card_completed_toggled(card_id: String, value: bool) -> void:
	var before: Array = cards.duplicate(true)
	for c in cards:
		if String(c.get("id", "")) == card_id:
			c["completed"] = value
			break
	_push_cards_history(before)


func _on_card_priority_changed(card_id: String, value: int) -> void:
	var before: Array = cards.duplicate(true)
	for c in cards:
		if String(c.get("id", "")) == card_id:
			c["priority"] = value
			break
	_rebuild_cards()
	_push_cards_history(before)


func _on_card_due_changed(card_id: String, due_unix: int) -> void:
	var before: Array = cards.duplicate(true)
	for c in cards:
		if String(c.get("id", "")) == card_id:
			if due_unix > 0:
				c["due_unix"] = due_unix
			else:
				c.erase("due_unix")
			break
	_rebuild_cards()
	_push_cards_history(before)


func _on_card_delete_requested(card_id: String) -> void:
	var before: Array = cards.duplicate(true)
	var keep: Array = []
	for c in cards:
		if String(c.get("id", "")) != card_id:
			keep.append(c)
	cards = keep
	_rebuild_cards()
	_push_cards_history(before)


func _push_cards_history(before: Array) -> void:
	var editor: Node = _find_editor()
	if editor != null:
		History.push_already_done(ModifyPropertyCommand.new(editor, item_id, "cards", before, cards.duplicate(true)))
		if editor.has_method("request_save"):
			editor.request_save()


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null


func _on_edit_begin() -> void:
	_pre_edit_title = title
	_title_edit.text = title
	_title_label.visible = false
	_title_edit.visible = true
	_title_edit.grab_focus()
	_title_edit.select_all()


func _on_edit_end() -> void:
	var new_title: String = _title_edit.text
	_title_edit.release_focus()
	_title_edit.visible = false
	_title_label.visible = true
	if new_title != _pre_edit_title:
		var editor: Node = _find_editor()
		if editor != null:
			History.push(ModifyPropertyCommand.new(editor, item_id, "title", _pre_edit_title, new_title))
		else:
			title = new_title
			_refresh_visuals()
	else:
		_refresh_visuals()


func _on_edit_focus_exited() -> void:
	if is_editing():
		end_edit()


func _on_edit_submitted(_t: String) -> void:
	if is_editing():
		end_edit()


func _on_selection_changed(selected: Array) -> void:
	if is_editing() and not selected.has(self):
		end_edit()


func _gui_input(event: InputEvent) -> void:
	if is_editing() or read_only:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and mb.double_click:
			var local := get_local_mouse_position()
			if local.y <= HEADER_HEIGHT:
				begin_edit()
				accept_event()
				return
	super._gui_input(event)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if String((data as Dictionary).get("kind", "")) != "todo_card":
		return false
	_position_drop_indicator(_index_for_drop_y(_at_position.y))
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	_position_drop_indicator(-1)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	if String(d.get("kind", "")) != "todo_card":
		return
	var source_list_id: String = String(d.get("source_list_id", ""))
	var card_id: String = String(d.get("card_id", ""))
	if source_list_id == "" or card_id == "":
		return
	var editor: Node = _find_editor()
	if editor == null:
		return
	var source: TodoListNode = editor.find_item_by_id(source_list_id) as TodoListNode
	if source == null:
		return
	var card_dict: Dictionary = (d.get("card_data", {}) as Dictionary).duplicate(true)
	var insert_index: int = _index_for_drop_y(at_position.y)
	if source == self:
		var src_before: Array = cards.duplicate(true)
		var current_idx: int = _find_card_index(card_id)
		if current_idx < 0:
			return
		var working: Array = cards.duplicate(true)
		working.remove_at(current_idx)
		var clamped: int = clamp(insert_index, 0, cards.size())
		if current_idx < clamped:
			clamped -= 1
		clamped = clamp(clamped, 0, working.size())
		working.insert(clamped, card_dict)
		cards = working
		_rebuild_cards()
		History.push_already_done(MoveTodoCardCommand.new(
			editor, item_id, item_id,
			src_before, src_before, cards.duplicate(true), cards.duplicate(true),
		))
		if editor.has_method("request_save"):
			editor.request_save()
		return
	var src_before2: Array = source.cards.duplicate(true)
	var tgt_before2: Array = cards.duplicate(true)
	source.cards = source.cards.filter(func(c: Dictionary) -> bool: return String(c.get("id", "")) != card_id)
	source._rebuild_cards()
	var clamped2: int = clamp(insert_index, 0, cards.size())
	cards.insert(clamped2, card_dict)
	_rebuild_cards()
	History.push_already_done(MoveTodoCardCommand.new(
		editor, source_list_id, item_id,
		src_before2, tgt_before2,
		source.cards.duplicate(true), cards.duplicate(true),
	))
	if editor.has_method("request_save"):
		editor.request_save()


func _index_for_drop_y(local_y: float) -> int:
	if _cards_container == null:
		return cards.size()
	var scroll_offset: Vector2 = Vector2.ZERO
	if _scroll != null:
		scroll_offset = _scroll.position - Vector2(0, _scroll.scroll_vertical)
	var cards_local_y: float = local_y - scroll_offset.y - _cards_container.position.y
	var idx: int = 0
	for child in _cards_container.get_children():
		if child == _drop_indicator:
			continue
		if not (child is Control):
			continue
		var c: Control = child
		var center_y: float = c.position.y + c.size.y * 0.5
		if cards_local_y < center_y:
			return idx
		idx += 1
	return cards.size()


func _find_card_index(card_id: String) -> int:
	for i in range(cards.size()):
		if String(cards[i].get("id", "")) == card_id:
			return i
	return -1


func _position_drop_indicator(index: int) -> void:
	if _drop_indicator == null:
		return
	if index < 0:
		_drop_indicator.visible = false
		_drop_indicator_index = -1
		return
	_drop_indicator.visible = true
	_drop_indicator_index = index
	var rows: Array = []
	for child in _cards_container.get_children():
		if child != _drop_indicator and child is Control:
			rows.append(child)
	_cards_container.move_child(_drop_indicator, min(index, rows.size()))


func serialize_payload() -> Dictionary:
	var out: Dictionary = {
		"title": title,
		"bg_color_custom": bg_color_custom,
		"accent_color_custom": accent_color_custom,
		"header_fg_color_custom": header_fg_color_custom,
		"cards": cards.duplicate(true),
	}
	if bg_color_custom:
		out["bg_color"] = ColorUtil.to_array(bg_color)
	if accent_color_custom:
		out["accent_color"] = ColorUtil.to_array(accent_color)
	if header_fg_color_custom:
		out["header_fg_color"] = ColorUtil.to_array(header_fg_color)
	return out


func deserialize_payload(d: Dictionary) -> void:
	title = String(d.get("title", title))
	_load_color_field(d, "bg_color", "bg_color_custom", LEGACY_BG, _set_bg)
	_load_color_field(d, "accent_color", "accent_color_custom", LEGACY_HEADER_BG, _set_accent)
	_load_color_field(d, "header_fg_color", "header_fg_color_custom", LEGACY_HEADER_FG, _set_header_fg)
	var cards_raw: Variant = d.get("cards", [])
	if typeof(cards_raw) == TYPE_ARRAY:
		cards = (cards_raw as Array).duplicate(true)
	if _title_label != null:
		_refresh_visuals()
		_rebuild_cards()


func _set_bg(c: Color) -> void:
	bg_color = c


func _set_accent(c: Color) -> void:
	accent_color = c


func _set_header_fg(c: Color) -> void:
	header_fg_color = c


func _load_color_field(d: Dictionary, color_key: String, custom_key: String, legacy: Color, setter: Callable) -> void:
	if d.has(custom_key):
		var is_custom: bool = bool(d[custom_key])
		set(custom_key, is_custom)
		if is_custom and d.has(color_key):
			setter.call(ColorUtil.from_array(d[color_key], legacy))
		return
	if not d.has(color_key):
		return
	var stored: Color = ColorUtil.from_array(d[color_key], legacy)
	var is_legacy: bool = stored == legacy
	set(custom_key, not is_legacy)
	if not is_legacy:
		setter.call(stored)


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"title":
			title = String(value)
			_refresh_visuals()
		"bg_color":
			if value == null:
				bg_color_custom = false
			else:
				bg_color = ColorUtil.from_array(value, bg_color)
				bg_color_custom = true
			_refresh_visuals()
		"accent_color":
			if value == null:
				accent_color_custom = false
			else:
				accent_color = ColorUtil.from_array(value, accent_color)
				accent_color_custom = true
			_refresh_visuals()
		"header_fg_color":
			if value == null:
				header_fg_color_custom = false
			else:
				header_fg_color = ColorUtil.from_array(value, header_fg_color)
				header_fg_color_custom = true
			_refresh_visuals()
		"cards":
			if typeof(value) == TYPE_ARRAY:
				cards = (value as Array).duplicate(true)
				_rebuild_cards()


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/todo_list/todo_list_inspector.tscn")
	var inst: TodoListInspector = scene.instantiate()
	inst.bind(self)
	return inst
