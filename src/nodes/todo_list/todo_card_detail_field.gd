class_name TodoCardDetailField
extends PanelContainer

signal changed(field_id: String, header: String, content: String)
signal removed(field_id: String)
signal move_requested(field_id: String, direction: int)

@onready var _header_edit: LineEdit = %HeaderEdit
@onready var _content_edit: TextEdit = %ContentEdit
@onready var _delete_button: Button = %DeleteButton
@onready var _move_up_button: Button = %MoveUpButton
@onready var _move_down_button: Button = %MoveDownButton

var field_id: String = ""
var _suppress: bool = false


func bind(data: Dictionary) -> void:
	field_id = String(data.get("id", ""))
	_suppress = true
	if _header_edit != null:
		_header_edit.text = String(data.get("header", ""))
	if _content_edit != null:
		_content_edit.text = String(data.get("content", ""))
	_suppress = false


func _ready() -> void:
	_header_edit.text_changed.connect(func(_t: String) -> void: _emit_change())
	_content_edit.text_changed.connect(_emit_change)
	_delete_button.pressed.connect(func() -> void: emit_signal("removed", field_id))
	_move_up_button.pressed.connect(func() -> void: emit_signal("move_requested", field_id, -1))
	_move_down_button.pressed.connect(func() -> void: emit_signal("move_requested", field_id, 1))


func _emit_change() -> void:
	if _suppress:
		return
	emit_signal("changed", field_id, _header_edit.text, _content_edit.text)
