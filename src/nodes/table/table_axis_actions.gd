class_name TableAxisActions
extends PanelContainer

signal action_requested(action: String)

const AXIS_ROW: String = "row"
const AXIS_COL: String = "col"

const ACTION_INSERT_BEFORE: String = "insert_before"
const ACTION_INSERT_AFTER: String = "insert_after"
const ACTION_DELETE: String = "delete"

@onready var _label: Label = %AxisLabel
@onready var _btn_before: Button = %InsertBeforeBtn
@onready var _btn_after: Button = %InsertAfterBtn
@onready var _btn_delete: Button = %DeleteBtn

var _axis: String = AXIS_ROW
var _index: int = -1
var _ready_done: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_before.pressed.connect(func() -> void: emit_signal("action_requested", ACTION_INSERT_BEFORE))
	_btn_after.pressed.connect(func() -> void: emit_signal("action_requested", ACTION_INSERT_AFTER))
	_btn_delete.pressed.connect(func() -> void: emit_signal("action_requested", ACTION_DELETE))
	_ready_done = true
	_apply_labels()


func configure(axis: String, index: int) -> void:
	_axis = axis
	_index = index
	if _ready_done:
		_apply_labels()


func current_axis() -> String:
	return _axis


func current_index() -> int:
	return _index


func _apply_labels() -> void:
	if _axis == AXIS_ROW:
		_label.text = "Row %d" % _index
		_btn_before.text = "Insert ↑"
		_btn_before.tooltip_text = "Insert row above"
		_btn_after.text = "Insert ↓"
		_btn_after.tooltip_text = "Insert row below"
		_btn_delete.text = "Delete row"
		_btn_delete.tooltip_text = "Delete this row"
	else:
		_label.text = "Col %d" % _index
		_btn_before.text = "Insert ←"
		_btn_before.tooltip_text = "Insert column to the left"
		_btn_after.text = "Insert →"
		_btn_after.tooltip_text = "Insert column to the right"
		_btn_delete.text = "Delete col"
		_btn_delete.tooltip_text = "Delete this column"
