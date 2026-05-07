class_name BulkPropertyEditor
extends RefCounted

const MIXED_SUFFIX: String = " (mixed)"


static func build_section(items: Array, editor: Node) -> Control:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	if items.is_empty():
		return v
	var first: BoardItem = items[0]
	var schema: Array = first.bulk_shareable_properties()
	if schema.is_empty():
		return v
	var sep: HSeparator = HSeparator.new()
	v.add_child(sep)
	var hdr: Label = Label.new()
	hdr.text = "%s shared (%d)" % [first.display_name(), items.size()]
	v.add_child(hdr)
	for raw in schema:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw
		var widget: Control = _build_widget(items, entry, editor)
		if widget != null:
			v.add_child(widget)
	return v


static func _build_widget(items: Array, entry: Dictionary, editor: Node) -> Control:
	var kind: String = String(entry.get("kind", ""))
	match kind:
		"color_with_reset":
			return _build_color_row(items, entry, editor, true)
		"color":
			return _build_color_row(items, entry, editor, false)
		"bool":
			return _build_bool_row(items, entry, editor)
		"int_range":
			return _build_int_range_row(items, entry, editor)
	return null


static func _build_color_row(items: Array, entry: Dictionary, editor: Node, with_reset: bool) -> Control:
	var key: String = String(entry["key"])
	var label_text: String = String(entry.get("label", key))
	var row: HBoxContainer = HBoxContainer.new()
	var lbl: Label = Label.new()
	lbl.text = label_text + (MIXED_SUFFIX if _values_mixed(items, key) else "")
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var picker: ColorPickerButton = ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(80, 0)
	picker.color = _initial_color(items[0], key, with_reset)
	row.add_child(picker)
	var pre_values: Dictionary = _snapshot_color_pre(items, key, with_reset)
	picker.color_changed.connect(func(c: Color) -> void:
		for it in items:
			(it as BoardItem).apply_property(key, ColorUtil.to_array(c))
	)
	picker.popup_closed.connect(func() -> void:
		var after: Variant = ColorUtil.to_array(picker.color)
		_commit_with_pre(items, editor, key, after, pre_values)
		lbl.text = label_text + (MIXED_SUFFIX if _values_mixed(items, key) else "")
	)
	if with_reset:
		var reset_btn: Button = Button.new()
		reset_btn.text = "↺"
		reset_btn.tooltip_text = "Reset to theme default"
		reset_btn.custom_minimum_size = Vector2(28, 0)
		row.add_child(reset_btn)
		reset_btn.pressed.connect(func() -> void:
			for it in items:
				(it as BoardItem).apply_property(key, null)
			_commit_with_pre(items, editor, key, null, pre_values)
			picker.color = _initial_color(items[0], key, true)
			lbl.text = label_text + (MIXED_SUFFIX if _values_mixed(items, key) else "")
		)
	return row


static func _build_bool_row(items: Array, entry: Dictionary, editor: Node) -> Control:
	var key: String = String(entry["key"])
	var label_text: String = String(entry.get("label", key))
	var row: HBoxContainer = HBoxContainer.new()
	var cb: CheckBox = CheckBox.new()
	cb.text = label_text + (MIXED_SUFFIX if _values_mixed(items, key) else "")
	cb.button_pressed = bool((items[0] as BoardItem).get(key))
	row.add_child(cb)
	cb.toggled.connect(func(p: bool) -> void:
		for it in items:
			var item: BoardItem = it
			var before: Variant = item.get(key)
			if bool(before) == p:
				continue
			if editor != null:
				History.push(ModifyPropertyCommand.new(editor, item.item_id, key, before, p))
			else:
				item.apply_property(key, p)
		if editor != null and editor.has_method("request_save"):
			editor.request_save()
		cb.text = label_text
	)
	return row


static func _build_int_range_row(items: Array, entry: Dictionary, editor: Node) -> Control:
	var key: String = String(entry["key"])
	var label_text: String = String(entry.get("label", key))
	var row: HBoxContainer = HBoxContainer.new()
	var lbl: Label = Label.new()
	lbl.text = label_text + (MIXED_SUFFIX if _values_mixed(items, key) else "")
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var spin: SpinBox = SpinBox.new()
	spin.min_value = float(entry.get("min", 1))
	spin.max_value = float(entry.get("max", 999))
	spin.step = float(entry.get("step", 1))
	spin.value = float((items[0] as BoardItem).get(key))
	spin.custom_minimum_size = Vector2(96, 0)
	row.add_child(spin)
	var pre_values: Dictionary = {}
	for it in items:
		var item: BoardItem = it
		pre_values[item.item_id] = item.get(key)
	spin.value_changed.connect(func(v: float) -> void:
		for it in items:
			(it as BoardItem).apply_property(key, int(v))
	)
	var commit_handler: Callable = func() -> void:
		var new_val: int = int(spin.value)
		for it in items:
			var item: BoardItem = it
			var before: Variant = pre_values.get(item.item_id, item.get(key))
			if int(before) == new_val:
				continue
			if editor != null:
				History.push_already_done(ModifyPropertyCommand.new(editor, item.item_id, key, before, new_val))
			pre_values[item.item_id] = new_val
		if editor != null and editor.has_method("request_save"):
			editor.request_save()
		lbl.text = label_text
	spin.get_line_edit().focus_exited.connect(commit_handler)
	spin.get_line_edit().text_submitted.connect(func(_t: String) -> void: commit_handler.call())
	return row


static func _initial_color(item: BoardItem, key: String, with_reset: bool) -> Color:
	if with_reset:
		var resolver_name: String = "resolved_" + key
		if item.has_method(resolver_name):
			return item.call(resolver_name)
	return item.get(key)


static func _values_mixed(items: Array, key: String) -> bool:
	if items.size() <= 1:
		return false
	var first: Variant = (items[0] as BoardItem).get(key)
	for i in range(1, items.size()):
		if (items[i] as BoardItem).get(key) != first:
			return true
	return false


static func _snapshot_color_pre(items: Array, key: String, with_reset: bool) -> Dictionary:
	var out: Dictionary = {}
	var custom_key: String = key + "_custom"
	for it in items:
		var item: BoardItem = it
		if with_reset and _has_property(item, custom_key) and not bool(item.get(custom_key)):
			out[item.item_id] = null
		else:
			out[item.item_id] = ColorUtil.to_array(item.get(key))
	return out


static func _commit_with_pre(items: Array, editor: Node, key: String, after_value: Variant, pre_values: Dictionary) -> void:
	if editor == null:
		return
	for it in items:
		var item: BoardItem = it
		var before: Variant = pre_values.get(item.item_id, null)
		if _values_equal_loose(before, after_value):
			continue
		History.push_already_done(ModifyPropertyCommand.new(editor, item.item_id, key, before, after_value))
		pre_values[item.item_id] = after_value
	if editor.has_method("request_save"):
		editor.request_save()


static func _has_property(item: BoardItem, name: String) -> bool:
	for p in item.get_property_list():
		if String((p as Dictionary).get("name", "")) == name:
			return true
	return false


static func _values_equal_loose(a: Variant, b: Variant) -> bool:
	if a == null and b == null:
		return true
	if a == null or b == null:
		return false
	return a == b
