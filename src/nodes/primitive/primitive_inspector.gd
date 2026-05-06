class_name PrimitiveInspector
extends VBoxContainer

@onready var _shape_option: OptionButton = %ShapeOption
@onready var _fill_check: CheckBox = %FillCheck
@onready var _fill_picker: ColorPickerButton = %FillPicker
@onready var _outline_picker: ColorPickerButton = %OutlinePicker
@onready var _outline_width_spin: SpinBox = %OutlineWidthSpin
@onready var _corner_radius_spin: SpinBox = %CornerRadiusSpin

var _item: PrimitiveNode
var _editor: Node
var _binders: Dictionary = {}
var _suppress_signals: bool = false


func bind(item: PrimitiveNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	_populate_shape_options()
	if _item == null:
		return
	_suppress_signals = true
	_shape_option.select(_index_of_shape(_item.shape))
	_fill_check.button_pressed = _item.fill_enabled
	_fill_picker.color = _item.fill_color
	_outline_picker.color = _item.outline_color
	_outline_width_spin.value = _item.outline_width
	_corner_radius_spin.value = _item.corner_radius
	_suppress_signals = false
	_binders["shape"] = PropertyBinder.new(_editor, _item, "shape", _item.shape)
	_binders["fill_enabled"] = PropertyBinder.new(_editor, _item, "fill_enabled", _item.fill_enabled)
	_binders["fill_color"] = PropertyBinder.new(_editor, _item, "fill_color", ColorUtil.to_array(_item.fill_color))
	_binders["outline_color"] = PropertyBinder.new(_editor, _item, "outline_color", ColorUtil.to_array(_item.outline_color))
	_binders["outline_width"] = PropertyBinder.new(_editor, _item, "outline_width", _item.outline_width)
	_binders["corner_radius"] = PropertyBinder.new(_editor, _item, "corner_radius", _item.corner_radius)
	_shape_option.item_selected.connect(_on_shape_selected)
	_fill_check.toggled.connect(_on_fill_toggled)
	_fill_picker.color_changed.connect(_on_fill_live)
	_fill_picker.popup_closed.connect(_on_fill_commit)
	_outline_picker.color_changed.connect(_on_outline_live)
	_outline_picker.popup_closed.connect(_on_outline_commit)
	_outline_width_spin.value_changed.connect(_on_outline_width)
	_corner_radius_spin.value_changed.connect(_on_corner_radius)


func _populate_shape_options() -> void:
	_shape_option.clear()
	_shape_option.add_item("Rectangle", PrimitiveNode.Shape.RECT)
	_shape_option.add_item("Rounded Rectangle", PrimitiveNode.Shape.ROUNDED_RECT)
	_shape_option.add_item("Ellipse", PrimitiveNode.Shape.ELLIPSE)
	_shape_option.add_item("Triangle", PrimitiveNode.Shape.TRIANGLE)
	_shape_option.add_item("Diamond", PrimitiveNode.Shape.DIAMOND)
	_shape_option.add_item("Line", PrimitiveNode.Shape.LINE)
	_shape_option.add_item("Arrow", PrimitiveNode.Shape.ARROW)


func _index_of_shape(s: int) -> int:
	for i in range(_shape_option.item_count):
		if _shape_option.get_item_id(i) == s:
			return i
	return 0


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null


func _on_shape_selected(index: int) -> void:
	if _suppress_signals:
		return
	var id: int = _shape_option.get_item_id(index)
	_binders["shape"].live(id)
	_binders["shape"].commit(id)


func _on_fill_toggled(pressed: bool) -> void:
	if _suppress_signals:
		return
	_binders["fill_enabled"].live(pressed)
	_binders["fill_enabled"].commit(pressed)


func _on_fill_live(c: Color) -> void:
	if _suppress_signals:
		return
	_binders["fill_color"].live(ColorUtil.to_array(c))


func _on_fill_commit() -> void:
	if _suppress_signals:
		return
	_binders["fill_color"].commit(ColorUtil.to_array(_fill_picker.color))


func _on_outline_live(c: Color) -> void:
	if _suppress_signals:
		return
	_binders["outline_color"].live(ColorUtil.to_array(c))


func _on_outline_commit() -> void:
	if _suppress_signals:
		return
	_binders["outline_color"].commit(ColorUtil.to_array(_outline_picker.color))


func _on_outline_width(value: float) -> void:
	if _suppress_signals:
		return
	_binders["outline_width"].live(value)
	_binders["outline_width"].commit(value)


func _on_corner_radius(value: float) -> void:
	if _suppress_signals:
		return
	_binders["corner_radius"].live(value)
	_binders["corner_radius"].commit(value)
