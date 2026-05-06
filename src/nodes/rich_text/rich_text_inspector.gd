class_name RichTextInspector
extends VBoxContainer

@onready var _bb_edit: TextEdit = %BBEdit
@onready var _font_size_spin: SpinBox = %FontSizeSpin
@onready var _bg_picker: ColorPickerButton = %BgPicker
@onready var _fg_picker: ColorPickerButton = %FgPicker
@onready var _format_toolbar: BBCodeToolbar = %FormatToolbar
@onready var _auto_width_check: CheckBox = %AutoWidthCheck
@onready var _auto_height_check: CheckBox = %AutoHeightCheck

var _item: RichTextNode
var _editor: Node
var _binders: Dictionary = {}
var _suppress_signals: bool = false


func bind(item: RichTextNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	if _item == null:
		return
	_suppress_signals = true
	_bb_edit.text = _item.bbcode_text
	_font_size_spin.value = _item.font_size
	_bg_picker.color = _item.resolved_bg_color()
	_fg_picker.color = _item.resolved_fg_color()
	_auto_width_check.button_pressed = _item.auto_width
	_auto_height_check.button_pressed = _item.auto_height
	_suppress_signals = false
	_binders["bbcode_text"] = PropertyBinder.new(_editor, _item, "bbcode_text", _item.bbcode_text)
	_binders["font_size"] = PropertyBinder.new(_editor, _item, "font_size", _item.font_size)
	_binders["bg_color"] = PropertyBinder.new(_editor, _item, "bg_color", ColorUtil.to_array(_item.resolved_bg_color()))
	_binders["fg_color"] = PropertyBinder.new(_editor, _item, "fg_color", ColorUtil.to_array(_item.resolved_fg_color()))
	_binders["auto_width"] = PropertyBinder.new(_editor, _item, "auto_width", _item.auto_width)
	_binders["auto_height"] = PropertyBinder.new(_editor, _item, "auto_height", _item.auto_height)
	_auto_width_check.toggled.connect(_on_auto_width)
	_auto_height_check.toggled.connect(_on_auto_height)
	_install_reset_button(_bg_picker, "bg_color", _item.resolved_bg_color)
	_install_reset_button(_fg_picker, "fg_color", _item.resolved_fg_color)
	ThemeManager.theme_applied.connect(_on_theme_applied)
	ThemeManager.node_palette_changed.connect(func(_a: Dictionary, _b: Dictionary) -> void: _on_theme_applied())
	_format_toolbar.bind(_bb_edit)
	_format_toolbar.text_changed.connect(_on_toolbar_changed)
	_bb_edit.text_changed.connect(_on_bb_live)
	_bb_edit.focus_exited.connect(_on_bb_commit)
	_font_size_spin.value_changed.connect(_on_font_size)
	_bg_picker.color_changed.connect(_on_bg_live)
	_bg_picker.popup_closed.connect(_on_bg_commit)
	_fg_picker.color_changed.connect(_on_fg_live)
	_fg_picker.popup_closed.connect(_on_fg_commit)


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null


func _on_bb_live() -> void:
	if _suppress_signals:
		return
	_binders["bbcode_text"].live(_bb_edit.text)


func _on_bb_commit() -> void:
	if _suppress_signals:
		return
	_binders["bbcode_text"].commit(_bb_edit.text)


func _on_toolbar_changed() -> void:
	if _suppress_signals:
		return
	_binders["bbcode_text"].live(_bb_edit.text)
	_binders["bbcode_text"].commit(_bb_edit.text)


func _on_font_size(value: float) -> void:
	if _suppress_signals:
		return
	var v: int = int(value)
	_binders["font_size"].live(v)
	_binders["font_size"].commit(v)


func _on_bg_live(c: Color) -> void:
	if _suppress_signals:
		return
	_binders["bg_color"].live(ColorUtil.to_array(c))


func _on_bg_commit() -> void:
	if _suppress_signals:
		return
	_binders["bg_color"].commit(ColorUtil.to_array(_bg_picker.color))


func _on_fg_live(c: Color) -> void:
	if _suppress_signals:
		return
	_binders["fg_color"].live(ColorUtil.to_array(c))


func _on_fg_commit() -> void:
	if _suppress_signals:
		return
	_binders["fg_color"].commit(ColorUtil.to_array(_fg_picker.color))


func _on_auto_width(pressed: bool) -> void:
	if _suppress_signals:
		return
	_binders["auto_width"].live(pressed)
	_binders["auto_width"].commit(pressed)


func _on_auto_height(pressed: bool) -> void:
	if _suppress_signals:
		return
	_binders["auto_height"].live(pressed)
	_binders["auto_height"].commit(pressed)


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
