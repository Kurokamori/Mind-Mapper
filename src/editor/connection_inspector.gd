class_name ConnectionInspector
extends VBoxContainer

@onready var _from_label: Label = %FromLabel
@onready var _to_label: Label = %ToLabel
@onready var _color_picker: ColorPickerButton = %ColorPicker
@onready var _thickness_spin: SpinBox = %ThicknessSpin
@onready var _style_option: OptionButton = %StyleOption
@onready var _arrow_end_check: CheckBox = %ArrowEndCheck
@onready var _arrow_start_check: CheckBox = %ArrowStartCheck
@onready var _label_edit: LineEdit = %LabelEdit
@onready var _label_size_spin: SpinBox = %LabelSizeSpin
@onready var _delete_button: Button = %DeleteButton

var _connection: Connection = null
var _editor: Node = null
var _suppress_signals: bool = false
var _pre_values: Dictionary = {}


func bind(connection: Connection, editor: Node) -> void:
	_connection = connection
	_editor = editor


func _ready() -> void:
	if _connection == null:
		return
	_populate_style_options()
	_suppress_signals = true
	_color_picker.color = _connection.color
	_thickness_spin.value = _connection.thickness
	_select_style(_connection.style)
	_arrow_end_check.button_pressed = _connection.arrow_end
	_arrow_start_check.button_pressed = _connection.arrow_start
	_label_edit.text = _connection.label
	_label_size_spin.value = _connection.label_font_size
	_refresh_endpoint_labels()
	_suppress_signals = false
	_capture_pre_values()
	_color_picker.color_changed.connect(_on_color_live)
	_color_picker.popup_closed.connect(_on_color_commit)
	_thickness_spin.value_changed.connect(_on_thickness_changed)
	_style_option.item_selected.connect(_on_style_selected)
	_arrow_end_check.toggled.connect(_on_arrow_end_toggled)
	_arrow_start_check.toggled.connect(_on_arrow_start_toggled)
	_label_edit.text_changed.connect(_on_label_live)
	_label_edit.focus_exited.connect(_on_label_commit)
	_label_size_spin.value_changed.connect(_on_label_size_changed)
	_delete_button.pressed.connect(_on_delete_pressed)


func _capture_pre_values() -> void:
	_pre_values["color"] = ColorUtil.to_array(_connection.color)
	_pre_values["thickness"] = _connection.thickness
	_pre_values["style"] = _connection.style
	_pre_values["arrow_end"] = _connection.arrow_end
	_pre_values["arrow_start"] = _connection.arrow_start
	_pre_values["label"] = _connection.label
	_pre_values["label_font_size"] = _connection.label_font_size


func _populate_style_options() -> void:
	_style_option.clear()
	_style_option.add_item("Bezier", 0)
	_style_option.set_item_metadata(0, Connection.STYLE_BEZIER)
	_style_option.add_item("Straight", 1)
	_style_option.set_item_metadata(1, Connection.STYLE_STRAIGHT)
	_style_option.add_item("Orthogonal", 2)
	_style_option.set_item_metadata(2, Connection.STYLE_ORTHOGONAL)


func _select_style(style_value: String) -> void:
	for i: int in range(_style_option.item_count):
		if String(_style_option.get_item_metadata(i)) == style_value:
			_style_option.select(i)
			return
	_style_option.select(0)


func _refresh_endpoint_labels() -> void:
	_from_label.text = "From: %s" % _resolve_item_label(_connection.from_item_id)
	_to_label.text = "To: %s" % _resolve_item_label(_connection.to_item_id)


func _resolve_item_label(item_id: String) -> String:
	if _editor == null or item_id == "":
		return "(unknown)"
	if not _editor.has_method("find_item_by_id"):
		return item_id.substr(0, 8)
	var item: BoardItem = _editor.find_item_by_id(item_id)
	if item == null:
		return "(missing)"
	return "%s · %s" % [item.display_name(), item.item_id.substr(0, 6)]


func _push_property_change(key: String, new_value: Variant) -> void:
	if _editor == null or _connection == null:
		return
	var old_value: Variant = _pre_values.get(key, null)
	if _values_equal(old_value, new_value):
		return
	History.push_already_done(ModifyConnectionPropertyCommand.new(_editor, _connection.id, key, old_value, new_value))
	_pre_values[key] = new_value
	if _editor.has_method("request_save"):
		_editor.request_save()


func _live_apply(key: String, new_value: Variant) -> void:
	if _connection == null or _editor == null:
		return
	_connection.apply_property(key, new_value)
	if _editor.has_method("notify_connection_updated"):
		_editor.notify_connection_updated(_connection)


func _values_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	return a == b


func _on_color_live(color: Color) -> void:
	if _suppress_signals:
		return
	_live_apply("color", ColorUtil.to_array(color))


func _on_color_commit() -> void:
	if _suppress_signals:
		return
	_push_property_change("color", ColorUtil.to_array(_color_picker.color))


func _on_thickness_changed(value: float) -> void:
	if _suppress_signals:
		return
	_live_apply("thickness", value)
	_push_property_change("thickness", value)


func _on_style_selected(index: int) -> void:
	if _suppress_signals:
		return
	var meta: String = String(_style_option.get_item_metadata(index))
	_live_apply("style", meta)
	_push_property_change("style", meta)


func _on_arrow_end_toggled(pressed: bool) -> void:
	if _suppress_signals:
		return
	_live_apply("arrow_end", pressed)
	_push_property_change("arrow_end", pressed)


func _on_arrow_start_toggled(pressed: bool) -> void:
	if _suppress_signals:
		return
	_live_apply("arrow_start", pressed)
	_push_property_change("arrow_start", pressed)


func _on_label_live(text_value: String) -> void:
	if _suppress_signals:
		return
	_live_apply("label", text_value)


func _on_label_commit() -> void:
	if _suppress_signals:
		return
	_push_property_change("label", _label_edit.text)


func _on_label_size_changed(value: float) -> void:
	if _suppress_signals:
		return
	_live_apply("label_font_size", int(value))
	_push_property_change("label_font_size", int(value))


func _on_delete_pressed() -> void:
	if _editor == null or _connection == null:
		return
	History.push(RemoveConnectionsCommand.new(_editor, [_connection]))
