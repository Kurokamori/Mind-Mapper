class_name InspectorPanel
extends DockablePanel

signal close_requested

const CONNECTION_INSPECTOR_SCENE: PackedScene = preload("res://src/editor/connection_inspector.tscn")

@onready var _title_label: Label = %TitleLabel
@onready var _close_button: Button = %CloseButton
@onready var _content: VBoxContainer = %Content
@onready var _empty_label: Label = %EmptyLabel
@onready var _scroll: ScrollContainer = %Scroll

var _current_item: BoardItem = null
var _current_connection: Connection = null
var _current_connection_set: Array = []
var _edit_mode_enabled: bool = true


func _ready() -> void:
	super._ready()
	SelectionBus.selection_changed.connect(_on_selection_changed)
	_close_button.pressed.connect(_on_close_pressed)
	_render_for([])


func _on_close_pressed() -> void:
	emit_signal("close_requested")


func _on_selection_changed(selected: Array) -> void:
	if not selected.is_empty():
		_current_connection = null
		_current_connection_set = []
	_render_for(selected)


func show_connection(connection: Connection, editor: Node) -> void:
	_current_connection = connection
	_current_connection_set = [] if connection == null else [connection]
	_clear_content()
	if connection == null:
		_render_for(SelectionBus.current())
		return
	_title_label.text = "Connection"
	_empty_label.visible = false
	_scroll.visible = true
	var inspector: ConnectionInspector = CONNECTION_INSPECTOR_SCENE.instantiate()
	inspector.bind(connection, editor)
	_content.add_child(inspector)
	_apply_read_only_to_subtree(_content, not _edit_mode_enabled)


func show_connections(connections: Array, editor: Node) -> void:
	_current_connection = null
	_current_connection_set = connections.duplicate()
	_clear_content()
	if connections.is_empty():
		_render_for(SelectionBus.current())
		return
	_title_label.text = "%d connections" % connections.size()
	_empty_label.visible = false
	_scroll.visible = true
	var bulk_scene: PackedScene = preload("res://src/editor/bulk_connection_inspector.tscn")
	var bulk: Control = bulk_scene.instantiate()
	if bulk.has_method("bind"):
		bulk.bind(connections, editor)
	_content.add_child(bulk)
	_apply_read_only_to_subtree(_content, not _edit_mode_enabled)


func _render_for(selected: Array) -> void:
	_clear_content()
	if _current_connection != null or not _current_connection_set.is_empty():
		return
	if selected.size() == 0:
		_title_label.text = "INSPECTOR"
		_empty_label.text = "No selection"
		_empty_label.visible = true
		_scroll.visible = false
		_current_item = null
		return
	if selected.size() > 1:
		_title_label.text = "%d items" % selected.size()
		_empty_label.visible = false
		_scroll.visible = true
		_current_item = null
		_attach_multi_selection_section(selected)
		return
	var item: BoardItem = selected[0]
	_current_item = item
	_title_label.text = "INSPECTOR"
	_empty_label.visible = false
	_scroll.visible = true
	var inspector: Control = item.build_inspector()
	if inspector != null:
		_content.add_child(inspector)
	else:
		var note: Label = Label.new()
		note.text = "No inspector"
		_content.add_child(note)
	_attach_lock_section(item)
	_attach_tag_section(item)
	_attach_link_section(item)
	_attach_backlinks_section(item)
	_attach_delete_section(item)
	_apply_read_only_to_subtree(_content, not _edit_mode_enabled)


func _attach_multi_selection_section(selected: Array) -> void:
	var v: VBoxContainer = VBoxContainer.new()
	var lbl: Label = Label.new(); lbl.text = "Multi-selection actions:"; v.add_child(lbl)
	var lock_btn: Button = Button.new(); lock_btn.text = "Lock all"; v.add_child(lock_btn)
	var unlock_btn: Button = Button.new(); unlock_btn.text = "Unlock all"; v.add_child(unlock_btn)
	var editor: Node = _find_editor_node()
	lock_btn.pressed.connect(func() -> void:
		for it in selected:
			if editor != null and not (it as BoardItem).locked:
				History.push(ModifyPropertyCommand.new(editor, (it as BoardItem).item_id, "locked", false, true))
	)
	unlock_btn.pressed.connect(func() -> void:
		for it in selected:
			if editor != null and (it as BoardItem).locked:
				History.push(ModifyPropertyCommand.new(editor, (it as BoardItem).item_id, "locked", true, false))
	)
	var tag_label: Label = Label.new(); tag_label.text = "Add tag to all"; v.add_child(tag_label)
	var tag_row: HBoxContainer = HBoxContainer.new()
	var tag_input: LineEdit = LineEdit.new(); tag_input.placeholder_text = "tag"; tag_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tag_row.add_child(tag_input)
	var add_btn: Button = Button.new(); add_btn.text = "Apply"; tag_row.add_child(add_btn)
	v.add_child(tag_row)
	add_btn.pressed.connect(func() -> void:
		var tag: String = tag_input.text.strip_edges()
		if tag == "" or editor == null: return
		for it in selected:
			var item: BoardItem = it
			var before: PackedStringArray = item.tags.duplicate()
			var present: bool = false
			for t in item.tags:
				if String(t) == tag:
					present = true; break
			if present: continue
			var after: PackedStringArray = item.tags.duplicate()
			after.append(tag)
			var before_arr: Array = []
			for t in before: before_arr.append(String(t))
			var after_arr: Array = []
			for t in after: after_arr.append(String(t))
			History.push(ModifyPropertyCommand.new(editor, item.item_id, "tags", before_arr, after_arr))
		Tags.notify_changed()
	)
	var delete_sep: HSeparator = HSeparator.new()
	v.add_child(delete_sep)
	var delete_btn: Button = Button.new()
	delete_btn.text = "Delete all (%d)" % selected.size()
	delete_btn.tooltip_text = "Remove all selected nodes from the board (undoable)"
	delete_btn.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
	delete_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.55, 0.55))
	delete_btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.35, 0.35))
	v.add_child(delete_btn)
	delete_btn.pressed.connect(func() -> void:
		if editor == null:
			return
		var snapshot: Array = []
		for it in selected:
			if it is BoardItem:
				snapshot.append(it)
		if snapshot.is_empty():
			return
		SelectionBus.clear()
		History.push(RemoveItemsCommand.new(editor, snapshot))
	)
	_content.add_child(v)
	_attach_shared_property_groups(selected, editor)
	_apply_read_only_to_subtree(_content, not _edit_mode_enabled)


func _attach_shared_property_groups(selected: Array, editor: Node) -> void:
	var groups: Dictionary = {}
	var order: Array = []
	for it in selected:
		var item: BoardItem = it
		if item == null:
			continue
		var schema: Array = item.bulk_shareable_properties()
		if schema.is_empty():
			continue
		var key: String = item.type_id if item.type_id != "" else item.display_name()
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		(groups[key] as Array).append(item)
	for key in order:
		var bucket: Array = groups[key]
		if bucket.size() < 2:
			continue
		var section: Control = BulkPropertyEditor.build_section(bucket, editor)
		if section != null:
			_content.add_child(section)


func _attach_lock_section(item: BoardItem) -> void:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var sep: HSeparator = HSeparator.new()
	v.add_child(sep)
	var row: HBoxContainer = HBoxContainer.new()
	var cb: CheckBox = CheckBox.new()
	cb.text = "Locked (no move / edit / delete)"
	cb.button_pressed = item.locked
	var editor: Node = _find_editor_node()
	cb.toggled.connect(func(p: bool) -> void:
		if p == item.locked: return
		if editor == null:
			item.locked = p
			item.queue_redraw()
			return
		History.push(ModifyPropertyCommand.new(editor, item.item_id, "locked", item.locked, p))
	)
	row.add_child(cb)
	v.add_child(row)
	_content.add_child(v)


func _attach_tag_section(item: BoardItem) -> void:
	var v: VBoxContainer = VBoxContainer.new()
	var hdr: Label = Label.new(); hdr.text = "Tags"; v.add_child(hdr)
	var tag_row: HBoxContainer = HBoxContainer.new()
	tag_row.add_theme_constant_override("separation", 4)
	for tag in item.tags:
		var pill: Button = Button.new()
		pill.text = "%s ×" % String(tag)
		var color: Color = Tags.color_for(String(tag))
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(4)
		pill.add_theme_stylebox_override("normal", sb)
		pill.add_theme_stylebox_override("hover", sb)
		pill.add_theme_stylebox_override("pressed", sb)
		var cur_tag: String = String(tag)
		pill.pressed.connect(func() -> void: _remove_tag(item, cur_tag))
		tag_row.add_child(pill)
	v.add_child(tag_row)
	var input_row: HBoxContainer = HBoxContainer.new()
	var le: LineEdit = LineEdit.new()
	le.placeholder_text = "add tag…"
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_row.add_child(le)
	var add: Button = Button.new(); add.text = "+"
	input_row.add_child(add)
	v.add_child(input_row)
	add.pressed.connect(func() -> void: _add_tag(item, le.text.strip_edges(), le))
	le.text_submitted.connect(func(t: String) -> void: _add_tag(item, t.strip_edges(), le))
	_content.add_child(v)


func _add_tag(item: BoardItem, tag: String, input: LineEdit) -> void:
	if tag == "":
		return
	for t in item.tags:
		if String(t) == tag:
			input.text = ""
			return
	var editor: Node = _find_editor_node()
	var before_arr: Array = []
	for t in item.tags: before_arr.append(String(t))
	var after_arr: Array = before_arr.duplicate()
	after_arr.append(tag)
	if editor == null:
		var ps: PackedStringArray = PackedStringArray()
		for t2 in after_arr: ps.append(String(t2))
		item.tags = ps
		item.queue_redraw()
	else:
		History.push(ModifyPropertyCommand.new(editor, item.item_id, "tags", before_arr, after_arr))
	input.text = ""
	Tags.notify_changed()
	_render_for(SelectionBus.current())


func _remove_tag(item: BoardItem, tag: String) -> void:
	var editor: Node = _find_editor_node()
	var before_arr: Array = []
	var after_arr: Array = []
	for t in item.tags:
		before_arr.append(String(t))
		if String(t) != tag:
			after_arr.append(String(t))
	if editor == null:
		var ps: PackedStringArray = PackedStringArray()
		for t2 in after_arr: ps.append(String(t2))
		item.tags = ps
		item.queue_redraw()
	else:
		History.push(ModifyPropertyCommand.new(editor, item.item_id, "tags", before_arr, after_arr))
	Tags.notify_changed()
	_render_for(SelectionBus.current())


func _attach_link_section(item: BoardItem) -> void:
	var scene: PackedScene = preload("res://src/editor/link_section.tscn")
	var link_section: LinkSection = scene.instantiate()
	var editor: Node = _find_editor_node()
	link_section.bind(item, editor)
	_content.add_child(link_section)


func _attach_backlinks_section(item: BoardItem) -> void:
	var scene: PackedScene = preload("res://src/editor/backlinks_section.tscn")
	var section: BacklinksSection = scene.instantiate()
	var editor: Node = _find_editor_node()
	section.bind(item, editor)
	_content.add_child(section)


func _attach_delete_section(item: BoardItem) -> void:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var sep: HSeparator = HSeparator.new()
	v.add_child(sep)
	var btn: Button = Button.new()
	btn.text = "Delete node"
	btn.tooltip_text = "Remove this node from the board (undoable)"
	btn.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.55, 0.55))
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.35, 0.35))
	var editor: Node = _find_editor_node()
	btn.pressed.connect(func() -> void:
		if editor == null or item == null:
			return
		SelectionBus.clear()
		History.push(RemoveItemsCommand.new(editor, [item]))
	)
	v.add_child(btn)
	_content.add_child(v)


func _find_editor_node() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null


func _clear_content() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()


func set_edit_mode_enabled(enabled: bool) -> void:
	_edit_mode_enabled = enabled
	_apply_read_only_to_subtree(_content, not enabled)


func _render_for_after_render() -> void:
	pass


func _apply_read_only_to_subtree(root: Node, read_only: bool) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child is LineEdit:
			(child as LineEdit).editable = not read_only
		elif child is TextEdit:
			(child as TextEdit).editable = not read_only
		elif child is SpinBox:
			(child as SpinBox).editable = not read_only
		elif child is BaseButton:
			(child as BaseButton).disabled = read_only
		elif child is ColorPickerButton:
			(child as ColorPickerButton).disabled = read_only
		elif child is Slider:
			(child as Slider).editable = not read_only
		if child.get_child_count() > 0:
			_apply_read_only_to_subtree(child, read_only)
