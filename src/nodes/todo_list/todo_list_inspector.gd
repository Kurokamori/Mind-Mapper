class_name TodoListInspector
extends VBoxContainer

@onready var _title_edit: LineEdit = %TitleEdit
@onready var _bg_picker: ColorPickerButton = %BgPicker
@onready var _accent_picker: ColorPickerButton = %AccentPicker
@onready var _header_fg_picker: ColorPickerButton = %HeaderFgPicker
@onready var _count_label: Label = %CountLabel
@onready var _clear_completed_button: Button = %ClearCompletedButton

var _item: TodoListNode
var _editor: Node
var _binders: Dictionary = {}
var _suppress_signals: bool = false


func bind(item: TodoListNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	if _item == null:
		return
	_suppress_signals = true
	_title_edit.text = _item.title
	_bg_picker.color = _item.resolved_bg_color()
	_accent_picker.color = _item.resolved_accent_color()
	_header_fg_picker.color = _item.resolved_header_fg_color()
	_refresh_count()
	_suppress_signals = false
	_binders["title"] = PropertyBinder.new(_editor, _item, "title", _item.title)
	_binders["bg_color"] = PropertyBinder.new(_editor, _item, "bg_color", ColorUtil.to_array(_item.resolved_bg_color()))
	_binders["accent_color"] = PropertyBinder.new(_editor, _item, "accent_color", ColorUtil.to_array(_item.resolved_accent_color()))
	_binders["header_fg_color"] = PropertyBinder.new(_editor, _item, "header_fg_color", ColorUtil.to_array(_item.resolved_header_fg_color()))
	_title_edit.text_changed.connect(func(t: String) -> void: _binders["title"].live(t))
	_title_edit.focus_exited.connect(func() -> void: _binders["title"].commit(_title_edit.text))
	_title_edit.text_submitted.connect(func(t: String) -> void: _binders["title"].commit(t))
	_install_color_picker(_bg_picker, "bg_color", _item.resolved_bg_color)
	_install_color_picker(_accent_picker, "accent_color", _item.resolved_accent_color)
	_install_color_picker(_header_fg_picker, "header_fg_color", _item.resolved_header_fg_color)
	_clear_completed_button.pressed.connect(_on_clear_completed)
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
	_suppress_signals = false


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null


func _refresh_count() -> void:
	if _item == null:
		return
	var done: int = 0
	for c in _item.cards:
		if bool(c.get("completed", false)):
			done += 1
	_count_label.text = "%d / %d completed" % [done, _item.cards.size()]


func _on_clear_completed() -> void:
	if _item == null:
		return
	var before: Array = _item.cards.duplicate(true)
	var keep: Array = []
	for c in _item.cards:
		if not bool(c.get("completed", false)):
			keep.append(c)
	if keep.size() == _item.cards.size():
		return
	var binder: PropertyBinder = PropertyBinder.new(_editor, _item, "cards", before)
	binder.live(keep)
	binder.commit(keep)
	_refresh_count()
