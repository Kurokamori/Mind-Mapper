class_name BlockStackNode
extends BoardItem

const HEADER_HEIGHT: float = 38.0
const PADDING: Vector2 = Vector2(8, 6)
const ADD_BUTTON_HEIGHT: float = 32.0
const ADD_BUTTON_BOTTOM_MARGIN: float = 10.0
const SCROLL_GAP: float = 8.0
const DARK_HEADER_BG: Color = Color(0.30, 0.20, 0.40, 1.0)
const LIGHT_HEADER_BG: Color = Color(0.72, 0.58, 0.88, 1.0)
const DARK_HEADER_FG: Color = Color(0.95, 0.96, 0.99, 1.0)
const LIGHT_HEADER_FG: Color = Color(0.10, 0.07, 0.16, 1.0)
const LEGACY_BG: Color = Color(0.12, 0.13, 0.16, 1.0)
const LEGACY_HEADER_BG: Color = DARK_HEADER_BG
const LEGACY_HEADER_FG: Color = DARK_HEADER_FG

@export var title: String = "Blocks"
@export var bg_color: Color = Color(0, 0, 0, 1)
@export var bg_color_custom: bool = false
@export var accent_color: Color = DARK_HEADER_BG
@export var accent_color_custom: bool = false
@export var header_fg_color: Color = DARK_HEADER_FG
@export var header_fg_color_custom: bool = false
@export var blocks: Array = []

@onready var _title_label: Label = %TitleLabel
@onready var _title_edit: LineEdit = %TitleEdit
@onready var _add_button: Button = %AddButton
@onready var _scroll: ScrollContainer = %BlocksScroll
@onready var _blocks_container: VBoxContainer = %BlocksContainer
@onready var _drop_indicator: ColorRect = %DropIndicator
@onready var _image_dialog: FileDialog = %ImageDialog
@onready var _embed_choice: ConfirmationDialog = %EmbedChoice

var _pre_edit_title: String = ""
var _pending_image_block_id: String = ""
var _pending_image_path: String = ""
var _selected_block_id: String = ""


func _ready() -> void:
	super._ready()
	ThemeManager.theme_applied.connect(_refresh_visuals)
	ThemeManager.node_palette_changed.connect(func(_a: Dictionary, _b: Dictionary) -> void: _refresh_visuals())
	_layout()
	_refresh_visuals()
	_rebuild_blocks()
	if read_only:
		return
	_title_edit.focus_exited.connect(_on_edit_focus_exited)
	_title_edit.text_submitted.connect(_on_edit_submitted)
	_add_button.pressed.connect(_on_add_pressed)
	_image_dialog.file_selected.connect(_on_image_selected)
	_embed_choice.add_cancel_button("Link")
	_embed_choice.confirmed.connect(_on_embed_confirmed)
	_embed_choice.canceled.connect(_on_link_chosen)
	SelectionBus.selection_changed.connect(_on_selection_changed)


func resolved_bg_color() -> Color:
	return bg_color if bg_color_custom else ThemeManager.node_bg_color()


func resolved_accent_color() -> Color:
	return accent_color if accent_color_custom else ThemeManager.heading_bg("block")


func resolved_header_fg_color() -> Color:
	return header_fg_color if header_fg_color_custom else ThemeManager.heading_fg("block")


func default_size() -> Vector2:
	return Vector2(380, 360)


func display_name() -> String:
	return "Block Stack"


func minimum_item_size() -> Vector2:
	return Vector2(280.0, HEADER_HEIGHT + ADD_BUTTON_HEIGHT + ADD_BUTTON_BOTTOM_MARGIN + SCROLL_GAP + 40.0)


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


func _rebuild_blocks() -> void:
	if _blocks_container == null:
		return
	for child in _blocks_container.get_children():
		if child == _drop_indicator:
			continue
		child.queue_free()
	var found_selected: bool = false
	for b in blocks:
		var row_scene: PackedScene = preload("res://src/nodes/block_stack/block_row.tscn")
		var row: BlockRow = row_scene.instantiate()
		row.bind(item_id, b)
		row.text_changed.connect(_on_block_text_changed)
		row.indent_requested.connect(_on_block_indent_requested)
		row.delete_requested.connect(_on_block_delete_requested)
		row.image_requested.connect(_on_block_image_requested)
		row.link_requested.connect(_on_block_link_requested)
		row.follow_link_requested.connect(_on_block_follow_link_requested)
		row.block_selected.connect(_on_row_selected)
		var bid: String = String(b.get("id", ""))
		if bid == _selected_block_id:
			row.highlighted = true
			found_selected = true
		_blocks_container.add_child(row)
	if not found_selected:
		_selected_block_id = ""
	_position_drop_indicator(-1)


func _on_add_pressed() -> void:
	var before: Array = blocks.duplicate(true)
	var insert_index: int = blocks.size()
	var indent_level: int = 0
	if _selected_block_id != "":
		var sel_idx: int = _find_block_index(_selected_block_id)
		if sel_idx >= 0:
			insert_index = sel_idx + 1
			indent_level = clamp(int(blocks[sel_idx].get("indent_level", 0)) + 1, 0, 6)
	elif blocks.size() > 0:
		indent_level = int(blocks[blocks.size() - 1].get("indent_level", 0))
	var nb: Dictionary = {
		"id": Uuid.v4(),
		"text": "",
		"indent_level": indent_level,
		"asset_name": "",
		"source_path": "",
		"link_target": {},
	}
	blocks.insert(insert_index, nb)
	_selected_block_id = String(nb["id"])
	_rebuild_blocks()
	_push_blocks_history(before)


func _on_row_selected(block_id: String) -> void:
	if _selected_block_id == block_id:
		return
	_selected_block_id = block_id
	for child in _blocks_container.get_children():
		if child is BlockRow:
			var row: BlockRow = child
			row.set_highlighted(row.block_id == block_id)


func _on_block_text_changed(block_id: String, new_text: String) -> void:
	for b in blocks:
		if String(b.get("id", "")) == block_id:
			if String(b.get("text", "")) == new_text:
				return
			break
	var before: Array = blocks.duplicate(true)
	for b in blocks:
		if String(b.get("id", "")) == block_id:
			b["text"] = new_text
			break
	_push_blocks_history(before)


func _on_block_indent_requested(block_id: String, delta: int) -> void:
	var before: Array = blocks.duplicate(true)
	var changed: bool = false
	for b in blocks:
		if String(b.get("id", "")) == block_id:
			var lvl: int = int(b.get("indent_level", 0))
			var new_lvl: int = clamp(lvl + delta, 0, 6)
			if new_lvl != lvl:
				b["indent_level"] = new_lvl
				changed = true
			break
	if not changed:
		return
	_rebuild_blocks()
	_push_blocks_history(before)


func _on_block_delete_requested(block_id: String) -> void:
	var before: Array = blocks.duplicate(true)
	blocks = blocks.filter(func(b: Dictionary) -> bool: return String(b.get("id", "")) != block_id)
	_rebuild_blocks()
	_push_blocks_history(before)


func _on_block_image_requested(block_id: String) -> void:
	_pending_image_block_id = block_id
	_image_dialog.popup_centered_ratio(0.7)


func _on_image_selected(path: String) -> void:
	_pending_image_path = path
	_embed_choice.popup_centered()


func _on_embed_confirmed() -> void:
	_apply_image_to_pending(true)


func _on_link_chosen() -> void:
	_apply_image_to_pending(false)


func _apply_image_to_pending(embed: bool) -> void:
	if _pending_image_block_id == "" or _pending_image_path == "":
		_pending_image_block_id = ""
		_pending_image_path = ""
		return
	var path: String = _pending_image_path
	var bid: String = _pending_image_block_id
	_pending_image_block_id = ""
	_pending_image_path = ""
	var before: Array = blocks.duplicate(true)
	var found: bool = false
	for b in blocks:
		if String(b.get("id", "")) == bid:
			if embed and AppState.current_project != null:
				var copied: String = AppState.current_project.copy_asset_into_project(path)
				if copied != "":
					b["asset_name"] = copied
					b["source_path"] = ""
				else:
					b["asset_name"] = ""
					b["source_path"] = path
			else:
				b["asset_name"] = ""
				b["source_path"] = path
			found = true
			break
	if not found:
		return
	_rebuild_blocks()
	_push_blocks_history(before)


func _on_block_link_requested(block_id: String) -> void:
	var editor: Node = _find_editor()
	if editor == null or not editor.has_method("open_link_picker_for"):
		return
	editor.open_link_picker_for(self, Callable(self, "_apply_link_to_block").bind(block_id))


func _apply_link_to_block(block_id: String, target: Dictionary) -> void:
	var before: Array = blocks.duplicate(true)
	var changed: bool = false
	for b in blocks:
		if String(b.get("id", "")) == block_id:
			if target.is_empty():
				b["link_target"] = {}
			else:
				b["link_target"] = target.duplicate(true)
			changed = true
			break
	if not changed:
		return
	_rebuild_blocks()
	_push_blocks_history(before)


func _on_block_follow_link_requested(block_id: String) -> void:
	var editor: Node = _find_editor()
	if editor == null:
		return
	for b in blocks:
		if String(b.get("id", "")) == block_id:
			var lt: Variant = b.get("link_target", null)
			if typeof(lt) != TYPE_DICTIONARY:
				return
			var ld: Dictionary = lt
			var kind: String = String(ld.get("kind", ""))
			var id: String = String(ld.get("id", ""))
			if kind == BoardItem.LINK_KIND_BOARD and id != "":
				AppState.navigate_to_board(id)
			elif kind == BoardItem.LINK_KIND_ITEM and id != "":
				var target_item: BoardItem = editor.find_item_by_id(id)
				if target_item != null:
					SelectionBus.set_single(target_item)
			return


func _push_blocks_history(before: Array) -> void:
	var editor: Node = _find_editor()
	if editor != null:
		History.push_already_done(ModifyPropertyCommand.new(editor, item_id, "blocks", before, blocks.duplicate(true)))
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
	if not selected.has(self):
		_clear_block_selection()


func _clear_block_selection() -> void:
	if _selected_block_id == "":
		return
	_selected_block_id = ""
	for child in _blocks_container.get_children():
		if child is BlockRow:
			(child as BlockRow).set_highlighted(false)


func _gui_input(event: InputEvent) -> void:
	if is_editing() or read_only:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var local := get_local_mouse_position()
			if mb.double_click and local.y <= HEADER_HEIGHT:
				begin_edit()
				accept_event()
				return
			if local.y > HEADER_HEIGHT:
				_clear_block_selection()
	super._gui_input(event)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if String((data as Dictionary).get("kind", "")) != "block_row":
		return false
	_position_drop_indicator(_index_for_drop_y(_at_position.y))
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	_position_drop_indicator(-1)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	if String(d.get("kind", "")) != "block_row":
		return
	var source_stack_id: String = String(d.get("source_stack_id", ""))
	var block_id: String = String(d.get("block_id", ""))
	if source_stack_id == "" or block_id == "":
		return
	var editor: Node = _find_editor()
	if editor == null:
		return
	var source: BlockStackNode = editor.find_item_by_id(source_stack_id) as BlockStackNode
	if source == null:
		return
	var block_dict: Dictionary = (d.get("block_data", {}) as Dictionary).duplicate(true)
	var insert_index: int = _index_for_drop_y(at_position.y)
	if source == self:
		var before_self: Array = blocks.duplicate(true)
		var current_idx: int = _find_block_index(block_id)
		if current_idx < 0:
			return
		var working: Array = blocks.duplicate(true)
		working.remove_at(current_idx)
		var clamped: int = clamp(insert_index, 0, blocks.size())
		if current_idx < clamped:
			clamped -= 1
		clamped = clamp(clamped, 0, working.size())
		working.insert(clamped, block_dict)
		blocks = working
		_rebuild_blocks()
		_push_blocks_history(before_self)
		return
	var src_before: Array = source.blocks.duplicate(true)
	var tgt_before: Array = blocks.duplicate(true)
	source.blocks = source.blocks.filter(func(b: Dictionary) -> bool: return String(b.get("id", "")) != block_id)
	source._rebuild_blocks()
	var clamped2: int = clamp(insert_index, 0, blocks.size())
	blocks.insert(clamped2, block_dict)
	_rebuild_blocks()
	History.push_already_done(BlockStackMoveCommand.new(
		editor, source_stack_id, item_id,
		src_before, tgt_before,
		source.blocks.duplicate(true), blocks.duplicate(true),
	))
	if editor.has_method("request_save"):
		editor.request_save()


func _index_for_drop_y(local_y: float) -> int:
	if _blocks_container == null:
		return blocks.size()
	var scroll_offset: Vector2 = Vector2.ZERO
	if _scroll != null:
		scroll_offset = _scroll.position - Vector2(0, _scroll.scroll_vertical)
	var local_rel_y: float = local_y - scroll_offset.y - _blocks_container.position.y
	var idx: int = 0
	for child in _blocks_container.get_children():
		if child == _drop_indicator:
			continue
		if not (child is Control):
			continue
		var c: Control = child
		var center_y: float = c.position.y + c.size.y * 0.5
		if local_rel_y < center_y:
			return idx
		idx += 1
	return blocks.size()


func _find_block_index(block_id: String) -> int:
	for i in range(blocks.size()):
		if String(blocks[i].get("id", "")) == block_id:
			return i
	return -1


func _position_drop_indicator(index: int) -> void:
	if _drop_indicator == null:
		return
	if index < 0:
		_drop_indicator.visible = false
		return
	_drop_indicator.visible = true
	var rows: Array = []
	for child in _blocks_container.get_children():
		if child != _drop_indicator and child is Control:
			rows.append(child)
	_blocks_container.move_child(_drop_indicator, min(index, rows.size()))


func serialize_payload() -> Dictionary:
	var out: Dictionary = {
		"title": title,
		"bg_color_custom": bg_color_custom,
		"accent_color_custom": accent_color_custom,
		"header_fg_color_custom": header_fg_color_custom,
		"blocks": blocks.duplicate(true),
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
	var raw: Variant = d.get("blocks", [])
	if typeof(raw) == TYPE_ARRAY:
		blocks = (raw as Array).duplicate(true)
	if _title_label != null:
		_refresh_visuals()
		_rebuild_blocks()


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
		"blocks":
			if typeof(value) == TYPE_ARRAY:
				blocks = (value as Array).duplicate(true)
				_rebuild_blocks()


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/block_stack/block_stack_inspector.tscn")
	var inst: BlockStackInspector = scene.instantiate()
	inst.bind(self)
	return inst
