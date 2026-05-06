class_name TextInspector
extends VBoxContainer

@onready var _text_edit: TextEdit = %TextEdit
@onready var _font_size_spin: SpinBox = %FontSizeSpin
@onready var _bg_picker: ColorPickerButton = %BgPicker
@onready var _fg_picker: ColorPickerButton = %FgPicker
@onready var _auto_width_check: CheckBox = %AutoWidthCheck
@onready var _auto_height_check: CheckBox = %AutoHeightCheck

var _item: TextNode
var _editor: Node
var _binders: Dictionary = {}
var _suppress_signals: bool = false


func bind(item: TextNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	if _item == null:
		return
	_suppress_signals = true
	_text_edit.text = _item.text
	_font_size_spin.value = _item.font_size
	_bg_picker.color = _item.resolved_bg_color()
	_fg_picker.color = _item.resolved_fg_color()
	_auto_width_check.button_pressed = _item.auto_width
	_auto_height_check.button_pressed = _item.auto_height
	_suppress_signals = false
	_binders["text"] = PropertyBinder.new(_editor, _item, "text", _item.text)
	_binders["font_size"] = PropertyBinder.new(_editor, _item, "font_size", _item.font_size)
	_binders["bg_color"] = PropertyBinder.new(_editor, _item, "bg_color", ColorUtil.to_array(_item.resolved_bg_color()))
	_binders["fg_color"] = PropertyBinder.new(_editor, _item, "fg_color", ColorUtil.to_array(_item.resolved_fg_color()))
	_binders["auto_width"] = PropertyBinder.new(_editor, _item, "auto_width", _item.auto_width)
	_binders["auto_height"] = PropertyBinder.new(_editor, _item, "auto_height", _item.auto_height)
	_auto_width_check.toggled.connect(func(pressed: bool) -> void:
		if _suppress_signals: return
		_binders["auto_width"].live(pressed)
		_binders["auto_width"].commit(pressed)
	)
	_auto_height_check.toggled.connect(func(pressed: bool) -> void:
		if _suppress_signals: return
		_binders["auto_height"].live(pressed)
		_binders["auto_height"].commit(pressed)
	)
	_text_edit.text_changed.connect(func() -> void: _binders["text"].live(_text_edit.text))
	_text_edit.focus_exited.connect(func() -> void: _binders["text"].commit(_text_edit.text))
	_font_size_spin.value_changed.connect(func(v: float) -> void:
		_binders["font_size"].live(int(v))
		_binders["font_size"].commit(int(v))
	)
	_bg_picker.color_changed.connect(func(c: Color) -> void:
		if _suppress_signals: return
		_binders["bg_color"].live(ColorUtil.to_array(c))
	)
	_bg_picker.popup_closed.connect(func() -> void:
		if _suppress_signals: return
		_binders["bg_color"].commit(ColorUtil.to_array(_bg_picker.color))
	)
	_fg_picker.color_changed.connect(func(c: Color) -> void:
		if _suppress_signals: return
		_binders["fg_color"].live(ColorUtil.to_array(c))
	)
	_fg_picker.popup_closed.connect(func() -> void:
		if _suppress_signals: return
		_binders["fg_color"].commit(ColorUtil.to_array(_fg_picker.color))
	)
	_install_reset_button(_bg_picker, "bg_color", _item.resolved_bg_color)
	_install_reset_button(_fg_picker, "fg_color", _item.resolved_fg_color)
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
	if not _item.fg_color_custom:
		_fg_picker.color = _item.resolved_fg_color()
	_suppress_signals = false


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null
