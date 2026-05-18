class_name ConnectorInspector
extends VBoxContainer

@onready var _style_option: OptionButton = %StyleOption
@onready var _color_picker: ColorPickerButton = %ColorPicker
@onready var _width_spin: SpinBox = %WidthSpin
@onready var _head_spin: SpinBox = %HeadSpin
@onready var _start_x_spin: SpinBox = %StartXSpin
@onready var _start_y_spin: SpinBox = %StartYSpin
@onready var _end_x_spin: SpinBox = %EndXSpin
@onready var _end_y_spin: SpinBox = %EndYSpin

var _item: ConnectorNode
var _editor: Node
var _binders: Dictionary = {}
var _suppress_signals: bool = false


func bind(item: ConnectorNode) -> void:
	_item = item
	_editor = EditorLocator.find_for(_item)


func _ready() -> void:
	ThemeManager.apply_relative_font_sizes(self, {"Header": 1.15})
	_populate_style_options()
	if _item == null:
		return
	_suppress_signals = true
	_style_option.select(_index_of_style(_item.style))
	_color_picker.color = _item.color
	_width_spin.value = _item.width
	_head_spin.value = _item.head_size
	var sw: Vector2 = _item.start_world()
	var ew: Vector2 = _item.end_world()
	_start_x_spin.value = sw.x
	_start_y_spin.value = sw.y
	_end_x_spin.value = ew.x
	_end_y_spin.value = ew.y
	_suppress_signals = false
	_binders["style"] = PropertyBinder.new(_editor, _item, "style", _item.style)
	_binders["color"] = PropertyBinder.new(_editor, _item, "color", ColorUtil.to_array(_item.color))
	_binders["width"] = PropertyBinder.new(_editor, _item, "width", _item.width)
	_binders["head_size"] = PropertyBinder.new(_editor, _item, "head_size", _item.head_size)
	_binders["start"] = PropertyBinder.new(_editor, _item, "start", [sw.x, sw.y])
	_binders["end"] = PropertyBinder.new(_editor, _item, "end", [ew.x, ew.y])
	_style_option.item_selected.connect(_on_style_selected)
	_color_picker.color_changed.connect(_on_color_live)
	_color_picker.popup_closed.connect(_on_color_commit)
	_width_spin.value_changed.connect(_on_width_changed)
	_head_spin.value_changed.connect(_on_head_changed)
	_start_x_spin.value_changed.connect(_on_start_changed)
	_start_y_spin.value_changed.connect(_on_start_changed)
	_end_x_spin.value_changed.connect(_on_end_changed)
	_end_y_spin.value_changed.connect(_on_end_changed)


func _populate_style_options() -> void:
	_style_option.clear()
	_style_option.add_item("Line", ConnectorNode.Style.LINE)
	_style_option.add_item("Arrow", ConnectorNode.Style.ARROW)


func _index_of_style(s: int) -> int:
	for i in range(_style_option.item_count):
		if _style_option.get_item_id(i) == s:
			return i
	return 0


func _on_style_selected(index: int) -> void:
	if _suppress_signals:
		return
	var id: int = _style_option.get_item_id(index)
	_binders["style"].live(id)
	_binders["style"].commit(id)


func _on_color_live(c: Color) -> void:
	if _suppress_signals:
		return
	_binders["color"].live(ColorUtil.to_array(c))


func _on_color_commit() -> void:
	if _suppress_signals:
		return
	_binders["color"].commit(ColorUtil.to_array(_color_picker.color))


func _on_width_changed(value: float) -> void:
	if _suppress_signals:
		return
	_binders["width"].live(value)
	_binders["width"].commit(value)


func _on_head_changed(value: float) -> void:
	if _suppress_signals:
		return
	_binders["head_size"].live(value)
	_binders["head_size"].commit(value)


func _on_start_changed(_value: float) -> void:
	if _suppress_signals:
		return
	var arr: Array = [_start_x_spin.value, _start_y_spin.value]
	_binders["start"].live(arr)
	_binders["start"].commit(arr)


func _on_end_changed(_value: float) -> void:
	if _suppress_signals:
		return
	var arr: Array = [_end_x_spin.value, _end_y_spin.value]
	_binders["end"].live(arr)
	_binders["end"].commit(arr)
