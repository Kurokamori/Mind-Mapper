class_name TodoListNode
extends BoardItem

const HEADER_HEIGHT: float = 40.0
const PADDING: Vector2 = Vector2(10, 8)
const ADD_BUTTON_HEIGHT: float = 32.0
const ADD_BUTTON_BOTTOM_MARGIN: float = 10.0
const SCROLL_GAP: float = 8.0
const BASE_MIN_WIDTH: float = 260.0
const EDITING_EXTRA_WIDTH: float = 140.0
const SCROLLBAR_BUFFER: float = 16.0
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
@export var card_bg_color: Color = TodoCardRow.NORMAL_BG
@export var card_bg_color_custom: bool = false
@export var card_fg_color: Color = TodoCardRow.NORMAL_FG
@export var card_fg_color_custom: bool = false
@export var completed_bg_color: Color = TodoCardRow.COMPLETED_BG
@export var completed_bg_color_custom: bool = false
@export var completed_fg_color: Color = TodoCardRow.COMPLETED_FG
@export var completed_fg_color_custom: bool = false
@export var multiline_text: bool = false
@export var cards: Array = []

@onready var _title_label: Label = %TitleLabel
@onready var _title_edit: LineEdit = %TitleEdit
@onready var _add_button: Button = %AddButton
@onready var _scroll: ScrollContainer = %CardsScroll
@onready var _cards_container: VBoxContainer = %CardsContainer
@onready var _drop_indicator: ColorRect = %DropIndicator

var _pre_edit_title: String = ""
var _drop_indicator_index: int = -1
var _edit_focus_count: int = 0
var _pre_edit_width: float = -1.0
var _auto_grown_width: float = -1.0
var _shrink_check_pending: bool = false


func _ready() -> void:
	super._ready()
	ThemeManager.apply_relative_font_size(_title_label, 1.15)
	ThemeManager.theme_applied.connect(_refresh_visuals)
	ThemeManager.node_palette_changed.connect(func(_a: Dictionary, _b: Dictionary) -> void: _refresh_visuals())
	_layout()
	_refresh_visuals()
	_rebuild_cards()
	if _cards_container != null and not _cards_container.minimum_size_changed.is_connected(_on_cards_minimum_size_changed):
		_cards_container.minimum_size_changed.connect(_on_cards_minimum_size_changed)
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


func resolved_card_bg_color() -> Color:
	return card_bg_color if card_bg_color_custom else ThemeManager.node_card_bg_color()


func resolved_card_fg_color() -> Color:
	return card_fg_color if card_fg_color_custom else ThemeManager.node_card_fg_color()


func resolved_completed_bg_color() -> Color:
	return completed_bg_color if completed_bg_color_custom else ThemeManager.node_card_completed_bg_color()


func resolved_completed_fg_color() -> Color:
	return completed_fg_color if completed_fg_color_custom else ThemeManager.node_card_completed_fg_color()


func default_size() -> Vector2:
	return Vector2(340, 400)


func display_name() -> String:
	return "Todo List"


func minimum_item_size() -> Vector2:
	var base_h: float = HEADER_HEIGHT + ADD_BUTTON_HEIGHT + ADD_BUTTON_BOTTOM_MARGIN + SCROLL_GAP + 40.0
	var width: float = BASE_MIN_WIDTH
	var content_w: float = _required_content_width()
	if content_w > width:
		width = content_w
	return Vector2(width, base_h)


func _required_content_width() -> float:
	if _cards_container == null:
		return 0.0
	return _cards_container.get_combined_minimum_size().x + PADDING.x * 2.0 + SCROLLBAR_BUFFER


func _on_cards_minimum_size_changed() -> void:
	_enforce_minimum_width()


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
	_apply_card_palette()
	queue_redraw()


func _apply_card_palette() -> void:
	if _cards_container == null:
		return
	var bg: Color = resolved_card_bg_color()
	var fg: Color = resolved_card_fg_color()
	var cbg: Color = resolved_completed_bg_color()
	var cfg: Color = resolved_completed_fg_color()
	for child in _cards_container.get_children():
		if child is TodoCardRow:
			(child as TodoCardRow).set_palette(bg, fg, cbg, cfg)


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
		row.multiline_text = multiline_text
		row.palette_bg = resolved_card_bg_color()
		row.palette_fg = resolved_card_fg_color()
		row.palette_completed_bg = resolved_completed_bg_color()
		row.palette_completed_fg = resolved_completed_fg_color()
		row.text_changed.connect(_on_card_text_changed)
		row.completed_toggled.connect(_on_card_completed_toggled)
		row.delete_requested.connect(_on_card_delete_requested)
		row.priority_changed.connect(_on_card_priority_changed)
		row.due_changed.connect(_on_card_due_changed)
		row.expand_toggled.connect(_on_card_expand_toggled)
		row.add_child_requested.connect(_on_card_add_child_requested)
		row.details_requested.connect(_on_card_details_requested)
		row.child_drop.connect(_on_card_child_drop)
		row.child_drop_into_self.connect(_on_card_child_drop_into_self)
		row.edit_focus_changed.connect(_on_card_edit_focus_changed)
		_cards_container.add_child.call_deferred(row)
	_enforce_minimum_width.call_deferred()
	_position_drop_indicator(-1)


func _mutate_and_push(card_id: String, mutator: Callable, rebuild: bool = false) -> void:
	var before: Array = cards.duplicate(true)
	var updated: Array = TodoCardData.mutate_card(cards, card_id, mutator)
	if updated == cards:
		return
	cards = updated
	if rebuild:
		_rebuild_cards()
	_push_cards_history(before)


func _on_add_pressed() -> void:
	var before: Array = cards.duplicate(true)
	cards.append(TodoCardData.make_default())
	_rebuild_cards()
	_push_cards_history(before)
	_grow_to_fit_content()


func _grow_to_fit_content() -> void:
	if _cards_container == null:
		return
	await get_tree().process_frame
	if _cards_container == null:
		return
	var content: Vector2 = _cards_container.get_combined_minimum_size()
	var required_h: float = HEADER_HEIGHT + SCROLL_GAP * 2.0 + content.y + ADD_BUTTON_HEIGHT + ADD_BUTTON_BOTTOM_MARGIN
	var required_w: float = content.x + PADDING.x * 2.0
	var new_size: Vector2 = size
	var changed: bool = false
	if new_size.y < required_h:
		new_size.y = required_h
		changed = true
	if new_size.x < required_w:
		new_size.x = required_w
		changed = true
	if changed:
		size = new_size
		_layout()


func _enforce_minimum_width() -> void:
	var min_w: float = minimum_item_size().x
	if size.x < min_w:
		size.x = min_w
		_layout()


func _on_card_edit_focus_changed(_card_id: String, focused: bool) -> void:
	if focused:
		_edit_focus_count += 1
		if _edit_focus_count == 1:
			_apply_editing_expand()
	else:
		_edit_focus_count = max(0, _edit_focus_count - 1)
		if _edit_focus_count == 0 and not _shrink_check_pending:
			_shrink_check_pending = true
			_deferred_shrink_check.call_deferred()


func _apply_editing_expand() -> void:
	var target_w: float = minimum_item_size().x + EDITING_EXTRA_WIDTH
	if size.x >= target_w:
		return
	if _pre_edit_width < 0.0:
		_pre_edit_width = size.x
	size.x = target_w
	_auto_grown_width = target_w
	_layout()


func _deferred_shrink_check() -> void:
	_shrink_check_pending = false
	if _edit_focus_count > 0:
		return
	if _pre_edit_width < 0.0:
		return
	if is_equal_approx(size.x, _auto_grown_width):
		var restore_w: float = max(_pre_edit_width, minimum_item_size().x)
		size.x = restore_w
		_layout()
	_pre_edit_width = -1.0
	_auto_grown_width = -1.0


func _on_card_text_changed(card_id: String, new_text: String) -> void:
	var existing: Dictionary = TodoCardData.find_card(cards, card_id)
	if existing.is_empty() or String(existing.get("text", "")) == new_text:
		return
	_mutate_and_push(card_id, func(c: Dictionary) -> void: c["text"] = new_text)


func _on_card_completed_toggled(card_id: String, value: bool) -> void:
	_mutate_and_push(card_id, func(c: Dictionary) -> void: c["completed"] = value)


func _on_card_priority_changed(card_id: String, value: int) -> void:
	_mutate_and_push(card_id, func(c: Dictionary) -> void: c["priority"] = value, true)


func _on_card_due_changed(card_id: String, due_unix: int) -> void:
	_mutate_and_push(card_id, func(c: Dictionary) -> void:
		if due_unix > 0:
			c["due_unix"] = due_unix
		else:
			c.erase("due_unix")
	, true)


func _on_card_delete_requested(card_id: String) -> void:
	var before: Array = cards.duplicate(true)
	var pkg: Dictionary = TodoCardData.remove_card(cards, card_id)
	var after: Array = pkg.get("cards", cards) as Array
	if (pkg.get("removed", {}) as Dictionary).is_empty():
		return
	cards = after
	_rebuild_cards()
	_push_cards_history(before)


func _on_card_expand_toggled(card_id: String, expanded: bool) -> void:
	_mutate_and_push(card_id, func(c: Dictionary) -> void: c["expanded"] = expanded)
	if expanded:
		_grow_to_fit_content()


func _on_card_add_child_requested(card_id: String) -> void:
	_mutate_and_push(card_id, func(c: Dictionary) -> void:
		var sub: Array = (c.get("subcards", []) as Array).duplicate(true)
		sub.append(TodoCardData.make_default())
		c["subcards"] = sub
		c["expanded"] = true
	, true)
	_grow_to_fit_content()


func _on_card_details_requested(card_id: String) -> void:
	var card: Dictionary = TodoCardData.find_card(cards, card_id)
	if card.is_empty():
		return
	var dlg: TodoCardDetailDialog = (preload("res://src/nodes/todo_list/todo_card_detail_dialog.tscn") as PackedScene).instantiate()
	dlg.bind(card)
	get_tree().root.add_child(dlg)
	dlg.applied.connect(_on_detail_applied)
	PopupSizer.popup_fit(dlg, {"preferred": Vector2i(560, 640)})


func _on_detail_applied(card_id: String, updated: Dictionary) -> void:
	_mutate_and_push(card_id, func(c: Dictionary) -> void:
		var sub: Array = c.get("subcards", []) as Array
		c["text"] = String(updated.get("text", c.get("text", "")))
		c["completed"] = bool(updated.get("completed", c.get("completed", false)))
		c["description"] = String(updated.get("description", ""))
		c["details"] = (updated.get("details", []) as Array).duplicate(true)
		if updated.has("due_unix") and int(updated.get("due_unix", 0)) > 0:
			c["due_unix"] = int(updated["due_unix"])
		else:
			c.erase("due_unix")
		c["subcards"] = sub
	, true)


func _on_card_child_drop(target_card_id: String, source_list_id: String, source_card_id: String, source_card_data: Dictionary, insert_index: int) -> void:
	_drop_card_into(target_card_id, source_list_id, source_card_id, source_card_data, insert_index)


func _on_card_child_drop_into_self(target_card_id: String, source_list_id: String, source_card_id: String, source_card_data: Dictionary) -> void:
	var target: Dictionary = TodoCardData.find_card(cards, target_card_id)
	var idx: int = (target.get("subcards", []) as Array).size() if not target.is_empty() else 0
	_drop_card_into(target_card_id, source_list_id, source_card_id, source_card_data, idx)


func _drop_card_into(target_card_id: String, source_list_id: String, source_card_id: String, source_card_data: Dictionary, insert_index: int) -> void:
	var editor: Node = _find_editor()
	if editor == null:
		return
	if source_list_id == item_id and source_card_id == target_card_id:
		return
	if source_list_id == item_id:
		var src_node: Dictionary = TodoCardData.find_card(cards, source_card_id)
		if not src_node.is_empty():
			var src_sub: Array = src_node.get("subcards", []) as Array
			if not TodoCardData.find_path(src_sub, target_card_id).is_empty():
				return
	if source_list_id == item_id:
		var before: Array = cards.duplicate(true)
		var removed_pkg: Dictionary = TodoCardData.remove_card(cards, source_card_id)
		var after_remove: Array = removed_pkg.get("cards", cards) as Array
		var card: Dictionary = (removed_pkg.get("removed", source_card_data) as Dictionary).duplicate(true)
		var target_path: Array = TodoCardData.find_path(after_remove, target_card_id)
		if target_path.is_empty():
			return
		var inserted: Array = TodoCardData.insert_at_path(after_remove, target_path, insert_index, card)
		cards = inserted
		_rebuild_cards()
		History.push_already_done(ModifyPropertyCommand.new(editor, item_id, "cards", before, cards.duplicate(true)))
		if editor.has_method("request_save"):
			editor.request_save()
		return
	var source: TodoListNode = editor.find_item_by_id(source_list_id) as TodoListNode
	if source == null:
		return
	var src_before: Array = source.cards.duplicate(true)
	var tgt_before: Array = cards.duplicate(true)
	var src_pkg: Dictionary = TodoCardData.remove_card(source.cards, source_card_id)
	source.cards = src_pkg.get("cards", source.cards) as Array
	source._rebuild_cards()
	var card2: Dictionary = (src_pkg.get("removed", source_card_data) as Dictionary).duplicate(true)
	var target_path2: Array = TodoCardData.find_path(cards, target_card_id)
	if target_path2.is_empty():
		return
	cards = TodoCardData.insert_at_path(cards, target_path2, insert_index, card2)
	_rebuild_cards()
	History.push_already_done(MoveTodoCardCommand.new(
		editor, source_list_id, item_id,
		src_before, tgt_before,
		source.cards.duplicate(true), cards.duplicate(true),
	))
	if editor.has_method("request_save"):
		editor.request_save()


func _push_cards_history(before: Array) -> void:
	var editor: Node = _find_editor()
	if editor != null:
		History.push_already_done(ModifyPropertyCommand.new(editor, item_id, "cards", before, cards.duplicate(true)))
		if editor.has_method("request_save"):
			editor.request_save()


func _find_editor() -> Node:
	return EditorLocator.find_for(self)


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
	var insert_index: int = _index_for_drop_y(at_position.y)
	if source == self:
		var src_before: Array = cards.duplicate(true)
		var pkg: Dictionary = TodoCardData.remove_card(cards, card_id)
		var after_remove: Array = pkg.get("cards", cards) as Array
		var removed: Dictionary = pkg.get("removed", {}) as Dictionary
		if removed.is_empty():
			return
		var clamped: int = clamp(insert_index, 0, after_remove.size() + 1)
		clamped = min(clamped, after_remove.size())
		cards = TodoCardData.insert_at_path(after_remove, [], clamped, removed)
		_rebuild_cards()
		History.push_already_done(ModifyPropertyCommand.new(editor, item_id, "cards", src_before, cards.duplicate(true)))
		if editor.has_method("request_save"):
			editor.request_save()
		return
	var src_before2: Array = source.cards.duplicate(true)
	var tgt_before2: Array = cards.duplicate(true)
	var src_pkg: Dictionary = TodoCardData.remove_card(source.cards, card_id)
	source.cards = src_pkg.get("cards", source.cards) as Array
	source._rebuild_cards()
	var card_dict: Dictionary = (src_pkg.get("removed", d.get("card_data", {})) as Dictionary).duplicate(true)
	var clamped2: int = clamp(insert_index, 0, cards.size())
	cards = TodoCardData.insert_at_path(cards, [], clamped2, card_dict)
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
		"card_bg_color_custom": card_bg_color_custom,
		"card_fg_color_custom": card_fg_color_custom,
		"completed_bg_color_custom": completed_bg_color_custom,
		"completed_fg_color_custom": completed_fg_color_custom,
		"multiline_text": multiline_text,
		"cards": cards.duplicate(true),
	}
	if bg_color_custom:
		out["bg_color"] = ColorUtil.to_array(bg_color)
	if accent_color_custom:
		out["accent_color"] = ColorUtil.to_array(accent_color)
	if header_fg_color_custom:
		out["header_fg_color"] = ColorUtil.to_array(header_fg_color)
	if card_bg_color_custom:
		out["card_bg_color"] = ColorUtil.to_array(card_bg_color)
	if card_fg_color_custom:
		out["card_fg_color"] = ColorUtil.to_array(card_fg_color)
	if completed_bg_color_custom:
		out["completed_bg_color"] = ColorUtil.to_array(completed_bg_color)
	if completed_fg_color_custom:
		out["completed_fg_color"] = ColorUtil.to_array(completed_fg_color)
	return out


func deserialize_payload(d: Dictionary) -> void:
	title = String(d.get("title", title))
	_load_color_field(d, "bg_color", "bg_color_custom", LEGACY_BG, _set_bg)
	_load_color_field(d, "accent_color", "accent_color_custom", LEGACY_HEADER_BG, _set_accent)
	_load_color_field(d, "header_fg_color", "header_fg_color_custom", LEGACY_HEADER_FG, _set_header_fg)
	_load_color_field(d, "card_bg_color", "card_bg_color_custom", TodoCardRow.NORMAL_BG, _set_card_bg)
	_load_color_field(d, "card_fg_color", "card_fg_color_custom", TodoCardRow.NORMAL_FG, _set_card_fg)
	_load_color_field(d, "completed_bg_color", "completed_bg_color_custom", TodoCardRow.COMPLETED_BG, _set_completed_bg)
	_load_color_field(d, "completed_fg_color", "completed_fg_color_custom", TodoCardRow.COMPLETED_FG, _set_completed_fg)
	if d.has("multiline_text"):
		multiline_text = bool(d["multiline_text"])
	var cards_raw: Variant = d.get("cards", [])
	if typeof(cards_raw) == TYPE_ARRAY:
		cards = TodoCardData.normalize_array(cards_raw as Array)
	if _title_label != null:
		_refresh_visuals()
		_rebuild_cards()


func _set_bg(c: Color) -> void:
	bg_color = c


func _set_accent(c: Color) -> void:
	accent_color = c


func _set_header_fg(c: Color) -> void:
	header_fg_color = c


func _set_card_bg(c: Color) -> void:
	card_bg_color = c


func _set_card_fg(c: Color) -> void:
	card_fg_color = c


func _set_completed_bg(c: Color) -> void:
	completed_bg_color = c


func _set_completed_fg(c: Color) -> void:
	completed_fg_color = c


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
		"card_bg_color":
			if value == null:
				card_bg_color_custom = false
			else:
				card_bg_color = ColorUtil.from_array(value, card_bg_color)
				card_bg_color_custom = true
			_refresh_visuals()
		"card_fg_color":
			if value == null:
				card_fg_color_custom = false
			else:
				card_fg_color = ColorUtil.from_array(value, card_fg_color)
				card_fg_color_custom = true
			_refresh_visuals()
		"completed_bg_color":
			if value == null:
				completed_bg_color_custom = false
			else:
				completed_bg_color = ColorUtil.from_array(value, completed_bg_color)
				completed_bg_color_custom = true
			_refresh_visuals()
		"completed_fg_color":
			if value == null:
				completed_fg_color_custom = false
			else:
				completed_fg_color = ColorUtil.from_array(value, completed_fg_color)
				completed_fg_color_custom = true
			_refresh_visuals()
		"multiline_text":
			multiline_text = bool(value)
			_rebuild_cards()
		"cards":
			if typeof(value) == TYPE_ARRAY:
				cards = TodoCardData.normalize_array(value as Array)
				_rebuild_cards()


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/todo_list/todo_list_inspector.tscn")
	var inst: TodoListInspector = scene.instantiate()
	inst.bind(self)
	return inst


func bulk_shareable_properties() -> Array:
	return [
		{"key": "bg_color", "label": "Background", "kind": "color_with_reset"},
		{"key": "accent_color", "label": "Header color", "kind": "color_with_reset"},
		{"key": "header_fg_color", "label": "Header text", "kind": "color_with_reset"},
		{"key": "card_bg_color", "label": "Card background", "kind": "color_with_reset"},
		{"key": "card_fg_color", "label": "Card text", "kind": "color_with_reset"},
		{"key": "completed_bg_color", "label": "Completed background", "kind": "color_with_reset"},
		{"key": "completed_fg_color", "label": "Completed text", "kind": "color_with_reset"},
		{"key": "multiline_text", "label": "Wrap text (multi-line)", "kind": "bool"},
	]
