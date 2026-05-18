class_name StickyInspector
extends VBoxContainer

@onready var _text_edit: TextEdit = %TextEdit
@onready var _font_size_spin: SpinBox = %FontSizeSpin
@onready var _h_align_option: OptionButton = %HAlignOption
@onready var _v_align_option: OptionButton = %VAlignOption
@onready var _color_buttons: Array[Button] = [
	%Color0 as Button,
	%Color1 as Button,
	%Color2 as Button,
	%Color3 as Button,
	%Color4 as Button,
	%Color5 as Button,
]

var _item: StickyNode = null
var _editor: Node = null
var _binders: Dictionary = {}
var _suppress_signals: bool = false


func bind(item: StickyNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	ThemeManager.apply_relative_font_sizes(self, {"Header": 1.15})
	if _item == null:
		return
	_suppress_signals = true
	_text_edit.text = _item.text
	_font_size_spin.value = _item.font_size
	_apply_color_swatches()
	_highlight_selected_color()
	_h_align_option.select(clampi(_item.h_align, 0, 2))
	_v_align_option.select(clampi(_item.v_align, 0, 2))
	_suppress_signals = false
	_binders["text"] = PropertyBinder.new(_editor, _item, "text", _item.text)
	_binders["font_size"] = PropertyBinder.new(_editor, _item, "font_size", _item.font_size)
	_binders["color_index"] = PropertyBinder.new(_editor, _item, "color_index", _item.color_index)
	_binders["h_align"] = PropertyBinder.new(_editor, _item, "h_align", _item.h_align)
	_binders["v_align"] = PropertyBinder.new(_editor, _item, "v_align", _item.v_align)
	_h_align_option.item_selected.connect(_on_h_align)
	_v_align_option.item_selected.connect(_on_v_align)
	_text_edit.text_changed.connect(_on_text_changed)
	_text_edit.focus_exited.connect(_on_text_committed)
	_font_size_spin.value_changed.connect(_on_font_size_changed)
	for i: int in range(_color_buttons.size()):
		var idx: int = i
		_color_buttons[i].pressed.connect(func() -> void: _on_color_picked(idx))


func _on_text_changed() -> void:
	if _suppress_signals:
		return
	_binders["text"].live(_text_edit.text)


func _on_text_committed() -> void:
	if _suppress_signals:
		return
	_binders["text"].commit(_text_edit.text)


func _on_font_size_changed(value: float) -> void:
	if _suppress_signals:
		return
	var v: int = int(value)
	_binders["font_size"].live(v)
	_binders["font_size"].commit(v)


func _on_h_align(idx: int) -> void:
	if _suppress_signals:
		return
	_binders["h_align"].live(idx)
	_binders["h_align"].commit(idx)


func _on_v_align(idx: int) -> void:
	if _suppress_signals:
		return
	_binders["v_align"].live(idx)
	_binders["v_align"].commit(idx)


func _on_color_picked(idx: int) -> void:
	if _suppress_signals:
		return
	_binders["color_index"].live(idx)
	_binders["color_index"].commit(idx)
	_highlight_selected_color()


func _apply_color_swatches() -> void:
	for i: int in range(_color_buttons.size()):
		var btn: Button = _color_buttons[i]
		var color: Color = StickyNode.COLOR_PALETTE[i]
		var normal: StyleBoxFlat = _swatch_style(color, false)
		var hover: StyleBoxFlat = _swatch_style(color.lightened(0.08), false)
		var pressed: StyleBoxFlat = _swatch_style(color.darkened(0.10), false)
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_stylebox_override("focus", _swatch_style(color, true))


func _highlight_selected_color() -> void:
	if _item == null:
		return
	for i: int in range(_color_buttons.size()):
		var color: Color = StickyNode.COLOR_PALETTE[i]
		var selected: bool = (i == _item.color_index)
		_color_buttons[i].add_theme_stylebox_override("normal", _swatch_style(color, selected))


func _swatch_style(color: Color, selected: bool) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(3)
	if selected:
		sb.set_border_width_all(2)
		sb.border_color = Color(0.10, 0.10, 0.12, 1.0)
	return sb


func _find_editor() -> Node:
	return EditorLocator.find_for(_item)
