class_name BulkConnectionInspector
extends VBoxContainer

@onready var _color_picker: ColorPickerButton = %ColorPicker
@onready var _thickness_spin: SpinBox = %ThicknessSpin
@onready var _style_opt: OptionButton = %StyleOpt
@onready var _arrow_end: CheckBox = %ArrowEnd
@onready var _arrow_start: CheckBox = %ArrowStart
@onready var _delete_btn: Button = %DeleteButton

var _connections: Array = []
var _editor: Node = null


func bind(connections: Array, editor: Node) -> void:
	_connections = connections.duplicate()
	_editor = editor


func _ready() -> void:
	if _connections.is_empty():
		return
	_style_opt.add_item("Bezier", 0)
	_style_opt.add_item("Straight", 1)
	_style_opt.add_item("Orthogonal", 2)
	var first: Connection = _connections[0]
	_color_picker.color = first.color
	_thickness_spin.value = first.thickness
	_style_opt.select(_style_to_index(first.style))
	_arrow_end.button_pressed = first.arrow_end
	_arrow_start.button_pressed = first.arrow_start
	_color_picker.color_changed.connect(_on_color)
	_thickness_spin.value_changed.connect(_on_thickness)
	_style_opt.item_selected.connect(_on_style)
	_arrow_end.toggled.connect(_on_arrow_end)
	_arrow_start.toggled.connect(_on_arrow_start)
	_delete_btn.pressed.connect(_on_delete)


func _style_to_index(s: String) -> int:
	match s:
		Connection.STYLE_STRAIGHT: return 1
		Connection.STYLE_ORTHOGONAL: return 2
	return 0


func _index_to_style(i: int) -> String:
	match i:
		1: return Connection.STYLE_STRAIGHT
		2: return Connection.STYLE_ORTHOGONAL
	return Connection.STYLE_BEZIER


func _on_color(c: Color) -> void:
	_apply_property("color", c)


func _on_thickness(v: float) -> void:
	_apply_property("thickness", v)


func _on_style(idx: int) -> void:
	_apply_property("style", _index_to_style(idx))


func _on_arrow_end(p: bool) -> void:
	_apply_property("arrow_end", p)


func _on_arrow_start(p: bool) -> void:
	_apply_property("arrow_start", p)


func _apply_property(key: String, value: Variant) -> void:
	if _editor == null:
		return
	for c in _connections:
		var conn: Connection = c
		var current: Variant = null
		match key:
			"color": current = conn.color
			"thickness": current = conn.thickness
			"style": current = conn.style
			"arrow_end": current = conn.arrow_end
			"arrow_start": current = conn.arrow_start
		if current == value:
			continue
		History.push(ModifyConnectionPropertyCommand.new(_editor, conn.id, key, current, value))


func _on_delete() -> void:
	if _editor == null:
		return
	History.push(RemoveConnectionsCommand.new(_editor, _connections.duplicate()))
