class_name MobileConnectionSheet
extends Control

signal connection_deleted(connection_id: String)
signal connection_changed(connection_id: String)

@onready var _label_edit: LineEdit = %LabelEdit
@onready var _thickness_slider: HSlider = %ThicknessSlider
@onready var _thickness_value: Label = %ThicknessValue
@onready var _color_picker: ColorPickerButton = %ColorPickerButton
@onready var _style_options: OptionButton = %StyleOptions
@onready var _arrow_start_check: CheckBox = %ArrowStartCheck
@onready var _arrow_end_check: CheckBox = %ArrowEndCheck
@onready var _delete_button: Button = %DeleteButton

var _board_view: MobileBoardView = null
var _connection_id: String = ""
var _applying: bool = false


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_options.clear()
	_style_options.add_item("Bezier", 0)
	_style_options.add_item("Straight", 1)
	_style_options.add_item("Orthogonal", 2)
	_label_edit.text_changed.connect(_on_label_changed)
	_thickness_slider.value_changed.connect(_on_thickness_changed)
	_color_picker.color_changed.connect(_on_color_changed)
	_style_options.item_selected.connect(_on_style_selected)
	_arrow_start_check.toggled.connect(_on_arrow_start_toggled)
	_arrow_end_check.toggled.connect(_on_arrow_end_toggled)
	_delete_button.pressed.connect(_on_delete_pressed)


func bind_connection(board_view: MobileBoardView, connection_id: String) -> void:
	_board_view = board_view
	_connection_id = connection_id
	_refresh()


func _refresh() -> void:
	if _board_view == null or _connection_id == "":
		return
	var c: Connection = _board_view.find_connection_by_id(_connection_id)
	if c == null:
		return
	_applying = true
	_label_edit.text = c.label
	_thickness_slider.min_value = 1.0
	_thickness_slider.max_value = 12.0
	_thickness_slider.step = 0.5
	_thickness_slider.value = c.thickness
	_thickness_value.text = "%.1f" % c.thickness
	_color_picker.color = c.color
	match c.style:
		Connection.STYLE_BEZIER:
			_style_options.select(0)
		Connection.STYLE_STRAIGHT:
			_style_options.select(1)
		Connection.STYLE_ORTHOGONAL:
			_style_options.select(2)
		_:
			_style_options.select(0)
	_arrow_start_check.button_pressed = c.arrow_start
	_arrow_end_check.button_pressed = c.arrow_end
	_applying = false


func _on_label_changed(new_text: String) -> void:
	if _applying or _board_view == null:
		return
	_board_view.update_connection_property(_connection_id, "label", new_text)
	connection_changed.emit(_connection_id)


func _on_thickness_changed(value: float) -> void:
	if _applying or _board_view == null:
		return
	_thickness_value.text = "%.1f" % value
	_board_view.update_connection_property(_connection_id, "thickness", value)
	connection_changed.emit(_connection_id)


func _on_color_changed(color: Color) -> void:
	if _applying or _board_view == null:
		return
	_board_view.update_connection_property(_connection_id, "color", [color.r, color.g, color.b, color.a])
	connection_changed.emit(_connection_id)


func _on_style_selected(index: int) -> void:
	if _applying or _board_view == null:
		return
	var style: String = Connection.STYLE_BEZIER
	match index:
		0:
			style = Connection.STYLE_BEZIER
		1:
			style = Connection.STYLE_STRAIGHT
		2:
			style = Connection.STYLE_ORTHOGONAL
	_board_view.update_connection_property(_connection_id, "style", style)
	connection_changed.emit(_connection_id)


func _on_arrow_start_toggled(pressed: bool) -> void:
	if _applying or _board_view == null:
		return
	_board_view.update_connection_property(_connection_id, "arrow_start", pressed)
	connection_changed.emit(_connection_id)


func _on_arrow_end_toggled(pressed: bool) -> void:
	if _applying or _board_view == null:
		return
	_board_view.update_connection_property(_connection_id, "arrow_end", pressed)
	connection_changed.emit(_connection_id)


func _on_delete_pressed() -> void:
	if _board_view == null:
		return
	var c: Connection = _board_view.find_connection_by_id(_connection_id)
	if c == null:
		return
	History.push(RemoveConnectionsCommand.new(_board_view, [c]))
	connection_deleted.emit(_connection_id)
