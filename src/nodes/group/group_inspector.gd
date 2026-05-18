class_name GroupInspector
extends VBoxContainer

@onready var _title_edit: LineEdit = %TitleEdit
@onready var _bg_picker: ColorPickerButton = %BgPicker
@onready var _title_bg_picker: ColorPickerButton = %TitleBgPicker
@onready var _title_fg_picker: ColorPickerButton = %TitleFgPicker

var _item: GroupNode
var _editor: Node
var _binders: Dictionary = {}
var _suppress_signals: bool = false


func bind(item: GroupNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	ThemeManager.apply_relative_font_sizes(self, {"Header": 1.15})
	if _item == null:
		return
	_suppress_signals = true
	_title_edit.text = _item.title
	_bg_picker.color = _item.resolved_bg_color()
	_title_bg_picker.color = _item.resolved_title_bg_color()
	_title_fg_picker.color = _item.resolved_title_fg_color()
	_suppress_signals = false
	_binders["title"] = PropertyBinder.new(_editor, _item, "title", _item.title)
	_binders["bg_color"] = PropertyBinder.new(_editor, _item, "bg_color", ColorUtil.to_array(_item.resolved_bg_color()))
	_binders["title_bg_color"] = PropertyBinder.new(_editor, _item, "title_bg_color", ColorUtil.to_array(_item.resolved_title_bg_color()))
	_binders["title_fg_color"] = PropertyBinder.new(_editor, _item, "title_fg_color", ColorUtil.to_array(_item.resolved_title_fg_color()))
	_title_edit.text_changed.connect(func(t: String) -> void: _binders["title"].live(t))
	_title_edit.text_submitted.connect(func(t: String) -> void: _binders["title"].commit(t))
	_title_edit.focus_exited.connect(func() -> void: _binders["title"].commit(_title_edit.text))
	_bg_picker.color_changed.connect(func(c: Color) -> void:
		if _suppress_signals: return
		_binders["bg_color"].live(ColorUtil.to_array(c))
	)
	_bg_picker.popup_closed.connect(func() -> void:
		if _suppress_signals: return
		_binders["bg_color"].commit(ColorUtil.to_array(_bg_picker.color))
	)
	_title_bg_picker.color_changed.connect(func(c: Color) -> void:
		if _suppress_signals: return
		_binders["title_bg_color"].live(ColorUtil.to_array(c))
	)
	_title_bg_picker.popup_closed.connect(func() -> void:
		if _suppress_signals: return
		_binders["title_bg_color"].commit(ColorUtil.to_array(_title_bg_picker.color))
	)
	_title_fg_picker.color_changed.connect(func(c: Color) -> void:
		if _suppress_signals: return
		_binders["title_fg_color"].live(ColorUtil.to_array(c))
	)
	_title_fg_picker.popup_closed.connect(func() -> void:
		if _suppress_signals: return
		_binders["title_fg_color"].commit(ColorUtil.to_array(_title_fg_picker.color))
	)
	_install_reset_button(_bg_picker, "bg_color", _item.resolved_bg_color)
	_install_reset_button(_title_bg_picker, "title_bg_color", _item.resolved_title_bg_color)
	_install_reset_button(_title_fg_picker, "title_fg_color", _item.resolved_title_fg_color)
	ThemeManager.theme_applied.connect(_on_theme_applied)
	ThemeManager.node_palette_changed.connect(func(_a: Dictionary, _b: Dictionary) -> void: _on_theme_applied())


func _install_reset_button(picker: ColorPickerButton, slot: String, resolver: Callable) -> void:
	var row: HBoxContainer = picker.get_parent() as HBoxContainer
	if row == null:
		return
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
	if not _item.title_bg_color_custom:
		_title_bg_picker.color = _item.resolved_title_bg_color()
	if not _item.title_fg_color_custom:
		_title_fg_picker.color = _item.resolved_title_fg_color()
	_suppress_signals = false


func _find_editor() -> Node:
	return EditorLocator.find_for(_item)
