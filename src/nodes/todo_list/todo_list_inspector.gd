class_name TodoListInspector
extends VBoxContainer

@onready var _title_edit: LineEdit = %TitleEdit
@onready var _bg_picker: ColorPickerButton = %BgPicker
@onready var _accent_picker: ColorPickerButton = %AccentPicker
@onready var _header_fg_picker: ColorPickerButton = %HeaderFgPicker
@onready var _card_bg_picker: ColorPickerButton = %CardBgPicker
@onready var _card_fg_picker: ColorPickerButton = %CardFgPicker
@onready var _completed_bg_picker: ColorPickerButton = %CompletedBgPicker
@onready var _completed_fg_picker: ColorPickerButton = %CompletedFgPicker
@onready var _count_label: Label = %CountLabel
@onready var _multiline_check: CheckBox = %MultilineCheck
@onready var _clear_completed_button: Button = %ClearCompletedButton
@onready var _completed_to_bottom_button: Button = %CompletedToBottomButton
@onready var _plain_text_edit_button: Button = %PlainTextEditButton

var _item: TodoListNode
var _editor: Node
var _binders: Dictionary = {}
var _suppress_signals: bool = false


func bind(item: TodoListNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	ThemeManager.apply_relative_font_sizes(self, {"Header": 1.15})
	if _item == null:
		return
	_suppress_signals = true
	_title_edit.text = _item.title
	_bg_picker.color = _item.resolved_bg_color()
	_accent_picker.color = _item.resolved_accent_color()
	_header_fg_picker.color = _item.resolved_header_fg_color()
	_card_bg_picker.color = _item.resolved_card_bg_color()
	_card_fg_picker.color = _item.resolved_card_fg_color()
	_completed_bg_picker.color = _item.resolved_completed_bg_color()
	_completed_fg_picker.color = _item.resolved_completed_fg_color()
	_refresh_count()
	_multiline_check.button_pressed = _item.multiline_text
	_suppress_signals = false
	_binders["title"] = PropertyBinder.new(_editor, _item, "title", _item.title)
	_binders["multiline_text"] = PropertyBinder.new(_editor, _item, "multiline_text", _item.multiline_text)
	_multiline_check.toggled.connect(func(p: bool) -> void:
		if _suppress_signals: return
		_binders["multiline_text"].live(p)
		_binders["multiline_text"].commit(p)
	)
	_binders["bg_color"] = PropertyBinder.new(_editor, _item, "bg_color", ColorUtil.to_array(_item.resolved_bg_color()))
	_binders["accent_color"] = PropertyBinder.new(_editor, _item, "accent_color", ColorUtil.to_array(_item.resolved_accent_color()))
	_binders["header_fg_color"] = PropertyBinder.new(_editor, _item, "header_fg_color", ColorUtil.to_array(_item.resolved_header_fg_color()))
	_binders["card_bg_color"] = PropertyBinder.new(_editor, _item, "card_bg_color", ColorUtil.to_array(_item.resolved_card_bg_color()))
	_binders["card_fg_color"] = PropertyBinder.new(_editor, _item, "card_fg_color", ColorUtil.to_array(_item.resolved_card_fg_color()))
	_binders["completed_bg_color"] = PropertyBinder.new(_editor, _item, "completed_bg_color", ColorUtil.to_array(_item.resolved_completed_bg_color()))
	_binders["completed_fg_color"] = PropertyBinder.new(_editor, _item, "completed_fg_color", ColorUtil.to_array(_item.resolved_completed_fg_color()))
	_title_edit.text_changed.connect(func(t: String) -> void: _binders["title"].live(t))
	_title_edit.focus_exited.connect(func() -> void: _binders["title"].commit(_title_edit.text))
	_title_edit.text_submitted.connect(func(t: String) -> void: _binders["title"].commit(t))
	_install_color_picker(_bg_picker, "bg_color", _item.resolved_bg_color)
	_install_color_picker(_accent_picker, "accent_color", _item.resolved_accent_color)
	_install_color_picker(_header_fg_picker, "header_fg_color", _item.resolved_header_fg_color)
	_install_color_picker(_card_bg_picker, "card_bg_color", _item.resolved_card_bg_color)
	_install_color_picker(_card_fg_picker, "card_fg_color", _item.resolved_card_fg_color)
	_install_color_picker(_completed_bg_picker, "completed_bg_color", _item.resolved_completed_bg_color)
	_install_color_picker(_completed_fg_picker, "completed_fg_color", _item.resolved_completed_fg_color)
	_clear_completed_button.pressed.connect(_on_clear_completed)
	_completed_to_bottom_button.pressed.connect(_on_completed_to_bottom)
	_plain_text_edit_button.pressed.connect(_on_plain_text_edit_pressed)
	ThemeManager.theme_applied.connect(_on_theme_applied)
	ThemeManager.node_palette_changed.connect(func(_a: Dictionary, _b: Dictionary) -> void: _on_theme_applied())


func _install_color_picker(picker: ColorPickerButton, slot: String, resolver: Callable) -> void:
	picker.color_changed.connect(func(c: Color) -> void:
		if _suppress_signals: return
		_binders[slot].live(ColorUtil.to_array(c))
	)
	picker.popup_closed.connect(func() -> void:
		if _suppress_signals: return
		_binders[slot].commit(ColorUtil.to_array(picker.color))
	)
	var row: HBoxContainer = picker.get_parent() as HBoxContainer
	if row != null:
		var btn: Button = Button.new()
		btn.text = "↺"
		btn.tooltip_text = "Reset to theme default"
		btn.custom_minimum_size = Vector2(28, 0)
		row.add_child(btn)
		btn.pressed.connect(func() -> void:
			_binders[slot].live(null)
			_binders[slot].commit(null)
			picker.color = resolver.call()
		)


func _on_theme_applied() -> void:
	if _item == null:
		return
	_suppress_signals = true
	if not _item.bg_color_custom:
		_bg_picker.color = _item.resolved_bg_color()
	if not _item.accent_color_custom:
		_accent_picker.color = _item.resolved_accent_color()
	if not _item.header_fg_color_custom:
		_header_fg_picker.color = _item.resolved_header_fg_color()
	if not _item.card_bg_color_custom:
		_card_bg_picker.color = _item.resolved_card_bg_color()
	if not _item.card_fg_color_custom:
		_card_fg_picker.color = _item.resolved_card_fg_color()
	if not _item.completed_bg_color_custom:
		_completed_bg_picker.color = _item.resolved_completed_bg_color()
	if not _item.completed_fg_color_custom:
		_completed_fg_picker.color = _item.resolved_completed_fg_color()
	_suppress_signals = false


func _find_editor() -> Node:
	return EditorLocator.find_for(_item)


func _refresh_count() -> void:
	if _item == null:
		return
	var v: Vector2i = TodoCardData.count_completed(_item.cards)
	_count_label.text = "%d / %d completed (incl. sub-items)" % [v.x, v.y]


func _on_clear_completed() -> void:
	if _item == null:
		return
	var before: Array = _item.cards.duplicate(true)
	var keep: Array = _strip_completed(_item.cards)
	if _serialize_for_compare(keep) == _serialize_for_compare(_item.cards):
		return
	var binder: PropertyBinder = PropertyBinder.new(_editor, _item, "cards", before)
	binder.live(keep)
	binder.commit(keep)
	_refresh_count()


func _on_completed_to_bottom() -> void:
	if _item == null:
		return
	var before: Array = _item.cards.duplicate(true)
	var sorted: Array = _sort_completed_to_bottom(before)
	if _serialize_for_compare(sorted) == _serialize_for_compare(_item.cards):
		return
	var binder: PropertyBinder = PropertyBinder.new(_editor, _item, "cards", before)
	binder.live(sorted)
	binder.commit(sorted)
	_refresh_count()


func _sort_completed_to_bottom(arr: Array) -> Array:
	var pending: Array = []
	var done: Array = []
	for c in arr:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = (c as Dictionary).duplicate(true)
		copy["subcards"] = _sort_completed_to_bottom(copy.get("subcards", []) as Array)
		if bool(copy.get("completed", false)):
			done.append(copy)
		else:
			pending.append(copy)
	var out: Array = []
	out.append_array(pending)
	out.append_array(done)
	return out


func _strip_completed(arr: Array) -> Array:
	var out: Array = []
	for c in arr:
		if bool(c.get("completed", false)):
			continue
		var copy: Dictionary = c.duplicate(true)
		copy["subcards"] = _strip_completed(copy.get("subcards", []) as Array)
		out.append(copy)
	return out


func _serialize_for_compare(arr: Array) -> String:
	return JSON.stringify(arr)


func _on_plain_text_edit_pressed() -> void:
	if _item == null:
		return
	var dlg_scene: PackedScene = preload("res://src/editor/dialogs/plain_text_outline_dialog.tscn")
	var dlg: PlainTextOutlineDialog = dlg_scene.instantiate()
	var initial: String = PlainTextOutline.encode_todos(_item.cards)
	dlg.bind("Edit %s as plain text" % _item.title, initial)
	get_tree().root.add_child(dlg)
	dlg.applied.connect(_on_plain_text_applied)
	PopupSizer.popup_fit(dlg, {"preferred": Vector2i(560, 520)})


func _on_plain_text_applied(text: String) -> void:
	if _item == null:
		return
	var before: Array = _item.cards.duplicate(true)
	var parsed: Array = PlainTextOutline.decode_todos(text, before)
	var normalized: Array = TodoCardData.normalize_array(parsed)
	if _serialize_for_compare(normalized) == _serialize_for_compare(_item.cards):
		return
	var binder: PropertyBinder = PropertyBinder.new(_editor, _item, "cards", before)
	binder.live(normalized)
	binder.commit(normalized)
	_refresh_count()
